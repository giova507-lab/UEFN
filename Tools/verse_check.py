#!/usr/bin/env python3
"""
Heuristic static checker for the Ride A Sea Beast Verse sources.

UEFN is the only real Verse compiler, and it runs on Windows inside the
editor. This script catches the mistakes that are cheap to find without it:

  * calls to extension methods / members that are not defined anywhere
    (e.g. G.Foo(...) where no `(G:sea_beast_game_device).Foo` exists);
  * `.Member(` calls that exist neither in this project nor in Epic's
    Fortnite / UnrealEngine / Verse API digests (hallucinated APIs);
  * bare function calls that are not defined in the project or digests;
  * local names that shadow module-level names (Verse forbids shadowing);
  * tabs / odd indentation;
  * types used in a file without the `using` that provides them.

Usage:
  python3 Tools/verse_check.py [--digests DIR] [Content/Verse]

The digests (Fortnite.digest.verse, UnrealEngine.digest.verse,
Verse.digest.verse) ship with UEFN; pass their folder with --digests.
"""
import argparse
import os
import re
import sys
from collections import defaultdict

IDENT = r"[A-Za-z_][A-Za-z0-9_]*"

# Names that are language keywords / intrinsics rather than digest symbols.
BUILTINS = {
    "if", "else", "then", "for", "loop", "break", "return", "case", "block",
    "race", "sync", "rush", "branch", "spawn", "defer", "set", "var", "not",
    "and", "or", "array", "map", "option", "logic", "true", "false", "class",
    "struct", "enum", "interface", "module", "using", "type", "where",
    "external", "self", "Self", "super", "int", "float", "string", "char",
    "void", "any", "comparable", "tuple", "subtype", "castable_subtype",
    "Abs", "ConcatenateMaps", "Concatenate", "event", "weak_map",
}

# Types -> module that provides them (checked against `using` lines).
TYPE_MODULES = {
    "color": "/Verse.org/Colors",
    "vector3": "SpatialMath",
    "rotation": "SpatialMath",
    "transform": "SpatialMath",
    "vector2": "/UnrealEngine.com/Temporary/SpatialMath",
    "widget": "/UnrealEngine.com/Temporary/UI",
    "canvas": "/UnrealEngine.com/Temporary/UI",
    "text_block": "/Fortnite.com/UI",
    "button_loud": "/Fortnite.com/UI",
    "creative_prop": "/Fortnite.com/Devices",
    "creative_device": "/Fortnite.com/Devices",
    "fort_character": "/Fortnite.com/Characters",
    "player_ui": "/UnrealEngine.com/Temporary/UI",
}


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def strip_comments_and_strings(line):
    """Removes `# comments` and string literal contents (keeps interpolations)."""
    out = []
    in_str = False
    depth = 0
    i = 0
    while i < len(line):
        c = line[i]
        if not in_str and c == "#":
            break
        if c == '"' and (i == 0 or line[i - 1] != "\\") and depth == 0:
            in_str = not in_str
            out.append('"')
            i += 1
            continue
        if in_str:
            if c == "{":
                depth += 1
                out.append(" ")
            elif c == "}" and depth > 0:
                depth -= 1
                out.append(" ")
            elif depth > 0:
                out.append(c)
            else:
                out.append(" ")
        else:
            out.append(c)
        i += 1
    return "".join(out)


def collect_digest_names(digest_dir):
    names = set()
    if not digest_dir:
        return names
    for fn in os.listdir(digest_dir):
        if not fn.endswith(".verse"):
            continue
        text = read(os.path.join(digest_dir, fn))
        for m in re.finditer(r"(?:^|[\s\(\)\.:])(" + IDENT + r")\s*<", text):
            names.add(m.group(1))
        for m in re.finditer(r"\)\.(" + IDENT + r")", text):
            names.add(m.group(1))
        for m in re.finditer(r"^\s*(" + IDENT + r")\s*(?::=|:)", text, re.M):
            names.add(m.group(1))
        for m in re.finditer(r"^\s+(" + IDENT + r")\s*$", text, re.M):
            names.add(m.group(1))  # enum values
    return names


class Project:
    def __init__(self, files):
        self.files = files
        self.module_names = set()
        self.types = set()
        self.ext = defaultdict(set)          # type -> extension method names
        self.members = defaultdict(set)      # class -> member names
        self.all_members = set()
        self.enum_values = set()
        self.parse()

    def parse(self):
        for path, text in self.files.items():
            lines = text.split("\n")
            current_class = None
            class_indent = -1
            in_enum = False
            for raw in lines:
                line = strip_comments_and_strings(raw)
                if not line.strip():
                    continue
                indent = len(line) - len(line.lstrip(" "))
                stripped = line.strip()
                if in_enum:
                    if stripped.startswith("}"):
                        in_enum = False
                    else:
                        for v in re.findall(IDENT, stripped):
                            self.enum_values.add(v)
                    continue
                if current_class and indent <= class_indent:
                    current_class = None
                m = re.match(r"^(" + IDENT + r")(?:<[^>]*>)*\s*:=\s*(class|struct|interface|enum)\b(.*)$", stripped)
                if m and indent == 0:
                    name, kind, rest = m.group(1), m.group(2), m.group(3)
                    self.types.add(name)
                    self.module_names.add(name)
                    if kind == "enum":
                        inline = re.search(r"\{(.*)\}", rest)
                        if inline:
                            for v in re.findall(IDENT, inline.group(1)):
                                self.enum_values.add(v)
                        elif rest.strip().endswith("{"):
                            in_enum = True
                    else:
                        current_class = name
                        class_indent = indent
                    continue
                m = re.match(r"^(" + IDENT + r")\s*:=\s*type\s*\{", stripped)
                if m and indent == 0:
                    self.types.add(m.group(1))
                    self.module_names.add(m.group(1))
                    continue
                m = re.match(r"^\((" + IDENT + r")\s*:\s*(" + IDENT + r")\)\.(" + IDENT + r")", stripped)
                if m and indent == 0:
                    self.ext[m.group(2)].add(m.group(3))
                    self.all_members.add(m.group(3))
                    continue
                if indent == 0:
                    m = re.match(r"^(?:var\s+)?(" + IDENT + r")(?:<[^>]*>)*\s*[\(:]", stripped)
                    if m:
                        self.module_names.add(m.group(1))
                    continue
                if current_class and indent > class_indent:
                    m = re.match(r"^(?:var(?:<[^>]*>)?\s+)?(" + IDENT + r")(?:<[^>]*>)*\s*[\(:]", stripped)
                    if m and not stripped.startswith("@"):
                        # only direct members (one indentation level deeper)
                        if indent == class_indent + 4:
                            self.members[current_class].add(m.group(1))
                            self.all_members.add(m.group(1))


def check_member_collisions(project, report):
    for cls, members in project.members.items():
        for name in members:
            if name in project.module_names and name not in project.types:
                report(cls, 0, "class member '%s' has the same name as a module-level definition" % name)


def check(project, digest_names, report):
    check_member_collisions(project, report)
    known_calls = project.module_names | digest_names | BUILTINS | project.types
    device_members = project.members["sea_beast_game_device"] | project.ext["sea_beast_game_device"]
    ui_members = project.members["player_ui_controller"] | project.ext["player_ui_controller"]
    session_members = project.members["player_session"]
    profile_members = project.members["player_profile"]
    mount_members = project.members["mount_runtime"]
    inherited_device = {"GetTransform", "GetGlobalTransform", "GetPlayspace", "TeleportTo", "MoveTo", "Hide", "Show", "OnBegin", "OnEnd", "SetGlobalTransform"}

    for path, text in project.files.items():
        rel = os.path.basename(path)
        usings = set(re.findall(r"using\s*\{\s*([^}]+?)\s*\}", text))
        clean = "\n".join(strip_comments_and_strings(l) for l in text.split("\n"))
        locals_in_file = set(re.findall(r"(" + IDENT + r")\s*:=", clean))
        locals_in_file |= set(re.findall(r"(?:var\s+)(" + IDENT + r")\s*:", clean))
        locals_in_file |= set(re.findall(r"[\(,]\s*(" + IDENT + r")\s*:\s*[\[\]?A-Za-z_(]", clean))
        locals_in_file |= set(re.findall(r"for\s*\(\s*(?:" + IDENT + r"\s*->\s*)?(" + IDENT + r")\s*:", clean))
        locals_in_file |= set(re.findall(r"(" + IDENT + r")\s*->\s*" + IDENT + r"\s*:", clean))
        for lineno, raw in enumerate(text.split("\n"), 1):
            if "\t" in raw:
                report(rel, lineno, "tab character (use spaces)")
            line = strip_comments_and_strings(raw)
            if not line.strip():
                continue
            indent = len(line) - len(line.lstrip(" "))
            if indent % 4 != 0:
                report(rel, lineno, "indentation is not a multiple of 4")
            for m in re.finditer(r"\bG\.(" + IDENT + r")", line):
                name = m.group(1)
                if name not in device_members and name not in inherited_device:
                    report(rel, lineno, "unknown game device member G.%s" % name)
            for m in re.finditer(r"\bGame\.(" + IDENT + r")", line):
                name = m.group(1)
                if name not in device_members and name not in inherited_device:
                    report(rel, lineno, "unknown game device member Game.%s" % name)
            for m in re.finditer(r"\bUI\.(" + IDENT + r")", line):
                name = m.group(1)
                if name not in ui_members:
                    report(rel, lineno, "unknown UI controller member UI.%s" % name)
            for m in re.finditer(r"\bSession\.(" + IDENT + r")", line):
                name = m.group(1)
                if name not in session_members:
                    report(rel, lineno, "unknown player_session member Session.%s" % name)
            for m in re.finditer(r"\b(?:Profile|P)\.(" + IDENT + r")", line):
                name = m.group(1)
                if name not in profile_members and not line.lstrip().startswith("(G"):
                    report(rel, lineno, "unknown player_profile member %s" % name)
            for m in re.finditer(r"\bMount\.(" + IDENT + r")", line):
                name = m.group(1)
                if name not in mount_members:
                    report(rel, lineno, "unknown mount_runtime member Mount.%s" % name)
            for m in re.finditer(r"\bM\.(" + IDENT + r")", line):
                name = m.group(1)
                if name not in mount_members and name not in profile_members:
                    report(rel, lineno, "unknown mount member M.%s" % name)
            # member calls on anything else
            for m in re.finditer(r"\.(" + IDENT + r")\s*[\(\[]", line):
                name = m.group(1)
                if name not in project.all_members and name not in digest_names and name not in known_calls:
                    report(rel, lineno, "method .%s( not found in project or digests" % name)
            # bare calls
            for m in re.finditer(r"(?<![\.\w])(" + IDENT + r")\s*[\(\[]", line):
                name = m.group(1)
                if name in known_calls or name in project.all_members or name in locals_in_file:
                    continue
                if name[0].isupper() and name not in project.enum_values:
                    report(rel, lineno, "bare call %s( not defined in project or digests" % name)
            # shadowing: local definitions that reuse a module-level name
            m = re.match(r"^\s+(?:var\s+)?(" + IDENT + r")\s*(?::=|:\s*[\[\]?A-Za-z_(])", line)
            if m and indent > 0:
                name = m.group(1)
                if name in project.module_names and name not in {"Game"}:
                    report(rel, lineno, "local '%s' shadows a module-level definition" % name)
        for type_name, module in TYPE_MODULES.items():
            if re.search(r"[:\s\(]" + type_name + r"\b", text):
                if not any(module in u for u in usings):
                    report(rel, 0, "uses type '%s' without a using for %s" % (type_name, module))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", nargs="?", default=os.path.join(os.path.dirname(__file__), "..", "Content", "Verse"))
    parser.add_argument("--digests", default=None)
    args = parser.parse_args()
    files = {}
    for fn in sorted(os.listdir(args.source)):
        if fn.endswith(".verse"):
            files[os.path.join(args.source, fn)] = read(os.path.join(args.source, fn))
    project = Project(files)
    digest_names = collect_digest_names(args.digests)
    findings = []

    def report(file, line, message):
        findings.append((file, line, message))

    check(project, digest_names, report)
    for f, l, m in findings:
        print("%s:%d: %s" % (f, l, m))
    print("%d finding(s) in %d file(s)" % (len(findings), len(files)))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
