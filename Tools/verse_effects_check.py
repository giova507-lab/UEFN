#!/usr/bin/env python3
"""
Effect-specifier checker for the Ride A Sea Beast Verse sources.

Verse rules this script approximates:
  * A function marked <transacts>, <reads>, <computes> or <converges> may
    only call functions that are themselves rollback-safe (they carry one of
    those effects). Device methods without effect specifiers are
    <no_rollback> and cannot be called from such functions.
  * <suspends> functions can only be called from <suspends> functions or
    inside spawn{...}.
  * <decides> functions are called with [] and non-<decides> functions with ().

It is a heuristic (it does not resolve overloads by type), so it reports a
call only when EVERY known overload of the callee violates the rule.

Usage: python3 Tools/verse_effects_check.py --digests DIR [Content/Verse]
"""
import argparse
import os
import re
import sys
from collections import defaultdict

IDENT = r"[A-Za-z_][A-Za-z0-9_]*"
SAFE = {"transacts", "reads", "computes", "converges"}
KEYWORDS = {"if", "for", "loop", "case", "race", "sync", "block", "spawn", "set",
            "not", "and", "or", "option", "array", "map", "logic", "return",
            "break", "then", "else", "branch", "rush", "defer", "type", "where"}


def strip(line):
    out, in_str, depth = [], False, 0
    for i, c in enumerate(line):
        if not in_str and c == "#":
            break
        if c == '"' and (i == 0 or line[i - 1] != "\\") and depth == 0:
            in_str = not in_str
            out.append('"')
            continue
        if in_str:
            if c == "{":
                depth += 1
                out.append(" ")
            elif c == "}" and depth > 0:
                depth -= 1
                out.append(" ")
            else:
                out.append(c if depth > 0 else " ")
        else:
            out.append(c)
    return "".join(out)


def effects_after_params(sig):
    """Returns the set of effect names in <..> groups after the parameter list."""
    depth, end = 0, -1
    start = sig.find("(")
    if start < 0:
        return set()
    for i in range(start, len(sig)):
        if sig[i] == "(":
            depth += 1
        elif sig[i] == ")":
            depth -= 1
            if depth == 0:
                end = i
                break
    if end < 0:
        return set()
    rest = sig[end + 1:]
    m = re.match(r"((?:\s*<[a-z_]+>)*)", rest)
    return set(re.findall(r"<([a-z_]+)>", m.group(1) if m else ""))


def parse_digest(digest_dir):
    info = defaultdict(list)  # name -> list of effect sets
    for fn in os.listdir(digest_dir):
        if not fn.endswith(".verse"):
            continue
        with open(os.path.join(digest_dir, fn), encoding="utf-8") as f:
            text = f.read()
        # Join multi-line signatures.
        text = re.sub(r"\(\s*\n\s*", "(", text)
        text = re.sub(r",\s*\n\s*", ", ", text)
        text = re.sub(r"\n\s*\)", ")", text)
        for line in text.split("\n"):
            s = line.strip()
            m = re.match(r"^(?:\([^)]*\)\.)?(?:\(/[^)]*:\))?(" + IDENT + r")((?:<[a-z_]+>)*)\s*\(", s)
            if m:
                name = m.group(1)
                effects = effects_after_params(s[m.start(1):])
                info[name].append(effects)
    return info


def parse_project(files):
    funcs = {}   # name -> list of (effects, file, line, body_lines)
    for path, text in files.items():
        lines = text.split("\n")
        i = 0
        while i < len(lines):
            raw = lines[i]
            line = strip(raw)
            indent = len(line) - len(line.lstrip(" "))
            s = line.strip()
            m = re.match(r"^(?:\((" + IDENT + r")\s*:\s*" + IDENT + r"\)\.)?(" + IDENT + r")((?:<[a-z_]+>)*)\s*\(", s)
            if m and (indent == 0 or indent == 4) and ("=" in s) and not s.startswith("if") and ":=" not in s.split("(")[0]:
                name = m.group(2)
                effects = effects_after_params(s[m.start(2):])
                body = []
                j = i + 1
                while j < len(lines):
                    l2 = strip(lines[j])
                    if l2.strip() == "":
                        j += 1
                        continue
                    ind2 = len(l2) - len(l2.lstrip(" "))
                    if ind2 <= indent:
                        break
                    body.append((j + 1, l2))
                    j += 1
                # single-line body after '='
                tail = s.split("=", 1)[1] if "=" in s else ""
                if tail.strip():
                    body.insert(0, (i + 1, tail))
                funcs.setdefault(name, []).append((effects, os.path.basename(path), i + 1, body))
                i = j
                continue
            i += 1
    return funcs


def is_safe(effects):
    return bool(effects & SAFE)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source", nargs="?", default=os.path.join(os.path.dirname(__file__), "..", "Content", "Verse"))
    ap.add_argument("--digests", required=True)
    args = ap.parse_args()
    files = {}
    for fn in sorted(os.listdir(args.source)):
        if fn.endswith(".verse"):
            with open(os.path.join(args.source, fn), encoding="utf-8") as f:
                files[os.path.join(args.source, fn)] = f.read()
    digest = parse_digest(args.digests)
    project = parse_project(files)
    findings = []

    def callee_effect_sets(name):
        sets = [e for (e, _, _, _) in project.get(name, [])]
        if not sets:
            sets = digest.get(name, [])
        return sets

    for name, defs in project.items():
        for effects, fname, lineno, body in defs:
            safe_ctx = is_safe(effects)
            suspends_ctx = "suspends" in effects
            for ln, text in body:
                # remove spawn{...} bodies (they may call suspends functions)
                text_no_spawn = re.sub(r"spawn\s*\{[^}]*\}", "", text)
                for m in re.finditer(r"(?<![\w])(\.)?(" + IDENT + r")\s*([\(\[])", text_no_spawn):
                    callee = m.group(2)
                    bracket = m.group(3)
                    if callee in KEYWORDS:
                        continue
                    sets = callee_effect_sets(callee)
                    if not sets:
                        continue
                    if safe_ctx and bracket in "([" and all(not is_safe(e) for e in sets):
                        # array/map indexing uses [] too; only flag () calls or known functions
                        findings.append((fname, ln, "%s is %s but calls %s which is not rollback-safe" % (name, "/".join(sorted(effects & SAFE)), callee)))
                    if not suspends_ctx and all("suspends" in e for e in sets):
                        findings.append((fname, ln, "%s is not <suspends> but calls <suspends> %s (wrap in spawn{})" % (name, callee)))
                    if bracket == "(" and all("decides" in e for e in sets) and callee in project:
                        findings.append((fname, ln, "%s calls <decides> %s with () - use []" % (name, callee)))
                    if bracket == "[" and all("decides" not in e for e in sets) and callee in project:
                        findings.append((fname, ln, "%s calls non-<decides> %s with []" % (name, callee)))
    # Failure contexts: if (...) / for (...) headers, logic{...} and
    # option{...} may only call rollback-safe functions (so never a
    # <suspends> one such as event.Await()).
    for path, text in files.items():
        fname = os.path.basename(path)
        for ln, raw in enumerate(text.split("\n"), 1):
            line = strip(raw)
            for m in re.finditer(r"\b(if|for)\s*\(|\b(?:logic|option)\{", line):
                start = m.end()
                depth = 1
                close = "}" if m.group(0).endswith("{") else ")"
                opener = "{" if close == "}" else "("
                i = start
                while i < len(line) and depth > 0:
                    if line[i] == opener:
                        depth += 1
                    elif line[i] == close:
                        depth -= 1
                    i += 1
                cond = line[start:i - 1]
                for c in re.finditer(r"(?<![\w])(" + IDENT + r")\s*([\(\[])", cond):
                    callee = c.group(1)
                    if callee in KEYWORDS:
                        continue
                    sets = callee_effect_sets(callee)
                    if sets and all(not is_safe(e) for e in sets):
                        findings.append((fname, ln, "failure context calls %s which is not rollback-safe" % callee))
    for f, l, msg in sorted(set(findings)):
        print("%s:%d: %s" % (f, l, msg))
    print("%d finding(s)" % len(set(findings)))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
