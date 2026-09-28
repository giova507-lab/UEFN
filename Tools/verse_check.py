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


DIGEST_ROOTS = {"Fortnite": "/Fortnite.com", "UnrealEngine": "/UnrealEngine.com", "Verse": "/Verse.org"}


def collect_module_exports(digest_dir):
    """Maps module import paths (e.g. /Verse.org/Simulation) to the names
    defined directly in that module, which `using` brings into scope."""
    exports = defaultdict(set)
    if not digest_dir:
        return exports
    for fn in os.listdir(digest_dir):
        if not fn.endswith(".verse"):
            continue
        root = next((v for k, v in DIGEST_ROOTS.items() if fn.startswith(k)), None)
        if root is None:
            continue
        stack = []  # (indent, module path)
        for raw in read(os.path.join(digest_dir, fn)).split("\n"):
            s = raw.rstrip()
            stripped = s.strip()
            if not stripped or stripped.startswith("#"):
                continue
            indent = len(s) - len(s.lstrip(" "))
            # A line at (or left of) a module's own indentation - normally its
            # closing brace - ends that module.
            while stack and indent <= stack[-1][0]:
                stack.pop()
            if stripped.startswith("}"):
                continue
            m = re.match(r"^\s*(?:\(/[^)]*:\))?(" + IDENT + r")<public>\s*:=\s*module\s*\{", s)
            if m:
                parent = stack[-1][1] if stack else root
                stack.append((indent, parent + "/" + m.group(1)))
                continue
            if stack and indent == stack[-1][0] + 2:
                body = s.strip()
                if body.startswith("(") and not body.startswith("(/"):
                    continue  # extension method: not a bare name
                mm = re.match(r"^(?:\(/[^)]*:\))?(" + IDENT + r")\s*<", body)
                if mm:
                    exports[stack[-1][1]].add(mm.group(1))
    return exports


def collect_digest_extensions(digest_dir):
    """Returns (extension method name -> module paths, member names defined
    inside digest classes). An extension method needs its module's `using`
    at the call site; a class member does not."""
    ext = defaultdict(set)
    class_members = set()
    if not digest_dir:
        return ext, class_members
    for fn in os.listdir(digest_dir):
        if not fn.endswith(".verse"):
            continue
        root = next((v for k, v in DIGEST_ROOTS.items() if fn.startswith(k)), None)
        if root is None:
            continue
        stack = []
        for raw in read(os.path.join(digest_dir, fn)).split("\n"):
            s = raw.rstrip()
            stripped = s.strip()
            if not stripped or stripped.startswith("#") or stripped.startswith("@"):
                continue
            indent = len(s) - len(s.lstrip(" "))
            while stack and indent <= stack[-1][0]:
                stack.pop()
            if stripped.startswith("}"):
                continue
            m = re.match(r"^\s*(?:\(/[^)]*:\))?(" + IDENT + r")<public>\s*:=\s*module\s*\{", s)
            if m:
                parent = stack[-1][1] if stack else root
                stack.append((indent, parent + "/" + m.group(1)))
                continue
            if not stack:
                continue
            em = re.match(r"^\(" + IDENT + r"\s*:[^)]*(?:\([^()]*\))?[^)]*\)\.(?:\(/[^)]*:\))?(" + IDENT + r")\s*<", stripped)
            if indent == stack[-1][0] + 2 and em:
                ext[em.group(1)].add(stack[-1][1])
            elif indent > stack[-1][0] + 2:
                mm = re.match(r"^(?:var(?:<[a-z_]+>)?\s+)?(?:\(/[^)]*:\))?(" + IDENT + r")\s*<", stripped)
                if mm:
                    class_members.add(mm.group(1))
    return ext, class_members


def check_value_imports(project, exports, digest_ext, digest_members, report):
    """Every free function / constant and every extension method a file uses
    must come from this project or from a module the file imports."""
    owners = defaultdict(set)
    for module, names in exports.items():
        for n in names:
            owners[n].add(module)
    project_ext = set()
    for names in project.ext.values():
        project_ext |= names
    defined = project.module_names | project.types | project.enum_values | project.all_members
    for path, text in project.files.items():
        rel = os.path.basename(path)
        usings = set(u.strip() for u in re.findall(r"using\s*\{\s*([^}]+?)\s*\}", text))
        usings.add("/Verse.org/Verse")
        clean_lines = [strip_comments_and_strings(l) for l in text.split("\n")]
        local_names = set()
        for l in clean_lines:
            local_names |= set(re.findall(r"(" + IDENT + r")\s*:=", l))
            local_names |= set(re.findall(r"[\(,]\s*(" + IDENT + r")\s*:\s*[\[\]?A-Za-z_(]", l))
            local_names |= set(re.findall(r"(" + IDENT + r")\s*->", l))
            local_names |= set(re.findall(r"var\s+(" + IDENT + r")\s*:", l))
        seen = set()
        for lineno, line in enumerate(clean_lines, 1):
            if line.strip().startswith("using"):
                continue
            line = re.sub(r"\(/[^)]*:\)" + IDENT, " ", line)  # qualified refs
            for m in re.finditer(r"\.(" + IDENT + r")\s*[\(\[]", line):
                n = m.group(1)
                if n in project_ext or n in project.all_members or n in digest_members or n not in digest_ext:
                    continue
                if not (digest_ext[n] & usings) and ("ext", n) not in seen:
                    seen.add(("ext", n))
                    report(rel, lineno, "extension method '.%s' needs using { %s }" % (n, sorted(digest_ext[n])[0]))
            for m in re.finditer(r"(?<![\w.'])(" + IDENT + r")\b", line):
                n = m.group(1)
                if n in defined or n in local_names or n not in owners:
                    continue
                if not (owners[n] & usings) and ("bare", n) not in seen:
                    seen.add(("bare", n))
                    report(rel, lineno, "'%s' needs using { %s }" % (n, sorted(owners[n])[0]))


def split_params(text):
    """Parameter names from the text inside a signature's parentheses."""
    names, depth, current = [], 0, ""
    for c in text:
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        if c == "," and depth == 0:
            names.append(current)
            current = ""
        else:
            current += c
    names.append(current)
    out = []
    for part in names:
        m = re.match(r"^\s*\??(" + IDENT + r")\s*:", part)
        if m:
            out.append(m.group(1))
    return out


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


def check_shadowing(project, exports, report):
    """Parameters, locals and loop variables may not reuse a name that is
    already visible: module-level names of this project or names brought in
    by the file's `using` statements."""
    for path, text in project.files.items():
        rel = os.path.basename(path)
        usings = re.findall(r"using\s*\{\s*([^}]+?)\s*\}", text)
        # /Verse.org/Verse is always in scope.
        imported = set(exports.get("/Verse.org/Verse", set()))
        for u in usings:
            imported |= exports.get(u.strip(), set())
        visible = project.module_names | imported
        for lineno, raw in enumerate(text.split("\n"), 1):
            line = strip_comments_and_strings(raw)
            stripped = line.strip()
            if not stripped:
                continue
            indent = len(line) - len(line.lstrip(" "))
            candidates = []
            # function / method parameters
            sig = re.match(r"^(?:\(" + IDENT + r"\s*:\s*" + IDENT + r"\)\.)?" + IDENT + r"(?:<[a-z_]+>)*\s*\((.*)\)\s*(?:<[a-z_]+>)*\s*:[^=]*=", stripped)
            if sig and indent in (0, 4):
                candidates += split_params(sig.group(1))
            # extension receiver name
            rec = re.match(r"^\((" + IDENT + r")\s*:\s*" + IDENT + r"\)\.", stripped)
            if rec and indent == 0:
                candidates.append(rec.group(1))
            # loop variables
            for m in re.finditer(r"for\s*\((.*)\)", stripped):
                for v in re.finditer(r"(?:^|,)\s*(?:(" + IDENT + r")\s*->\s*)?(" + IDENT + r")\s*(?::|:=)", m.group(1)):
                    candidates += [n for n in v.groups() if n]
            # locals inside bodies
            if indent > 0:
                loc = re.match(r"^(?:var\s+)?(" + IDENT + r")\s*(?::=|:\s*[\[\]?A-Za-z_(])", stripped)
                if loc and not sig:
                    candidates.append(loc.group(1))
            for name in candidates:
                if name in visible and name not in {"Game", "Self"} and name not in project.types:
                    where = "an imported name" if name in imported and name not in project.module_names else "a module-level definition"
                    report(rel, lineno, "'%s' shadows %s" % (name, where))


def check_member_shadowing(project, report):
    """Inside a class method, or an extension method of a class, a parameter,
    local or loop variable may not reuse a member name of that class."""
    for path, text in project.files.items():
        rel = os.path.basename(path)
        lines = [strip_comments_and_strings(l) for l in text.split("\n")]
        current_class = None
        i = 0
        while i < len(lines):
            line = lines[i]
            stripped = line.strip()
            indent = len(line) - len(line.lstrip(" "))
            owner = None
            if stripped and indent == 0:
                m = re.match(r"^(" + IDENT + r")(?:<[^>]*>)*\s*:=\s*class\b", stripped)
                current_class = m.group(1) if m else None
                ext = re.match(r"^\(" + IDENT + r"\s*:\s*(" + IDENT + r")\)\." + IDENT, stripped)
                if ext:
                    owner = ext.group(1)
            elif stripped and indent == 4 and current_class:
                if re.match(r"^" + IDENT + r"(?:<[^>]*>)*\s*\(.*\)\s*(?:<[^>]*>)*\s*:[^=]*=", stripped):
                    owner = current_class
            if not owner or not project.members.get(owner):
                i += 1
                continue
            names = project.members[owner]
            sig = stripped.split(")", 1)[0] if stripped.startswith("(") else stripped
            header = stripped[len(stripped.split(")")[0]) + 1:] if stripped.startswith("(") else stripped
            params_text = re.search(r"\((.*)\)\s*(?:<[a-z_]+>)*\s*:[^=]*=", header)
            if params_text:
                for p in split_params(params_text.group(1)):
                    if p in names:
                        report(rel, i + 1, "parameter '%s' reuses a member of %s" % (p, owner))
            j = i + 1
            while j < len(lines):
                body = lines[j]
                if body.strip():
                    body_indent = len(body) - len(body.lstrip(" "))
                    if body_indent <= indent:
                        break
                    for m in re.finditer(r"(?:^|[\s(,])(" + IDENT + r")\s*:=", body):
                        if m.group(1) in names:
                            report(rel, j + 1, "local '%s' reuses a member of %s" % (m.group(1), owner))
                    for m in re.finditer(r"for\s*\(\s*(?:(" + IDENT + r")\s*->\s*)?(" + IDENT + r")\s*:", body):
                        for n in m.groups():
                            if n and n in names:
                                report(rel, j + 1, "loop variable '%s' reuses a member of %s" % (n, owner))
                j += 1
            i = j if owner != current_class else i + 1


def check_type_imports(project, exports, report):
    """A type written in an annotation (Name:type) must be defined in this
    project or come from a module the file imports with `using`."""
    owners = defaultdict(set)  # exported name -> module paths
    for module, names in exports.items():
        for n in names:
            owners[n].add(module)
    for path, text in project.files.items():
        rel = os.path.basename(path)
        usings = set(u.strip() for u in re.findall(r"using\s*\{\s*([^}]+?)\s*\}", text))
        usings.add("/Verse.org/Verse")
        clean = "\n".join(strip_comments_and_strings(l) for l in text.split("\n"))
        # Drop explicitly qualified references such as (/Verse.org/SpatialMath:)vector3.
        clean = re.sub(r"\(/[^)]*:\)" + IDENT, " ", clean)
        seen = set()
        for m in re.finditer(r"(?<![:=])\s*:(?!=)\s*\??((?:\[[^\]]*\])*)(" + IDENT + r")\b", clean):
            name = m.group(2)
            if name in seen or name in project.types or name in project.module_names:
                continue
            seen.add(name)
            modules = owners.get(name)
            if modules and not (modules & usings):
                report(rel, 0, "type '%s' needs using { %s }" % (name, sorted(modules)[0]))


def check_callbacks(project, report):
    """Only class methods are passed as callbacks (Subscribe(Handler.Method));
    an extension method is not used as a function value."""
    ext_names = set()
    for names in project.ext.values():
        ext_names |= names
    for path, text in project.files.items():
        rel = os.path.basename(path)
        for lineno, raw in enumerate(text.split("\n"), 1):
            line = strip_comments_and_strings(raw)
            for m in re.finditer(r"Subscribe\(\s*(?:" + IDENT + r"\.)?(" + IDENT + r")\s*\)", line):
                if m.group(1) in ext_names:
                    report(rel, lineno, "extension method '%s' passed as a callback - forward it from a class method" % m.group(1))


def check_import_collisions(project, exports, report):
    """A module-level definition of this project may not have the same name
    as a definition that one of the files imports with `using` (the name
    would be ambiguous there)."""
    ours = project.module_names | project.types
    for path, text in project.files.items():
        rel = os.path.basename(path)
        usings = set(u.strip() for u in re.findall(r"using\s*\{\s*([^}]+?)\s*\}", text))
        usings.add("/Verse.org/Verse")
        for u in sorted(usings):
            for name in sorted(exports.get(u, set()) & ours):
                report(rel, 0, "'%s' is defined in this project and also imported from %s" % (name, u))


def check(project, digest_names, report, exports=None, digest_ext=None, digest_members=None):
    check_member_collisions(project, report)
    check_member_shadowing(project, report)
    check_callbacks(project, report)
    if exports:
        check_shadowing(project, exports, report)
        check_type_imports(project, exports, report)
        check_import_collisions(project, exports, report)
        check_value_imports(project, exports, digest_ext or {}, digest_members or set(), report)
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
            if re.search(r"[:\s\(]" + type_name + r"\b", clean):
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
    exports = collect_module_exports(args.digests)
    digest_ext, digest_members = collect_digest_extensions(args.digests)
    findings = []

    def report(file, line, message):
        findings.append((file, line, message))

    check(project, digest_names, report, exports, digest_ext, digest_members)
    for f, l, m in findings:
        print("%s:%d: %s" % (f, l, m))
    print("%d finding(s) in %d file(s)" % (len(findings), len(files)))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
