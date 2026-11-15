#!/usr/bin/env python3
"""Check a Windows install tree before it is packaged.

Every function a program or DLL of the tree takes from a DLL shipped in the same tree
must be exported by that DLL. Windows refuses to start the program otherwise
("entry point not found"), which a successful build does not reveal.

usage: check-dlls.py <install dir> [objdump]
"""
import collections
import os
import re
import subprocess
import sys

root = sys.argv[1]
objdump = sys.argv[2] if len(sys.argv) > 2 else "objdump"

binaries = [os.path.join(d, f) for d, _, files in os.walk(root) for f in files
            if f.lower().endswith((".dll", ".exe"))]
exports = {}
imports = {}
for path in binaries:
    out = subprocess.run([objdump, "-p", path], capture_output=True, text=True, errors="replace").stdout
    exported = set()
    imported = collections.defaultdict(set)
    mode = None
    dll = None
    for line in out.splitlines():
        if "DLL Name:" in line:
            dll = line.split("DLL Name:")[1].strip().lower()
            mode = "import"
            continue
        if "[Ordinal/Name Pointer] Table" in line:
            mode = "export"
            continue
        if line.startswith(("The Function Table", "PE File Base Relocations")):
            mode = None
        if mode == "export":
            m = re.match(r"\s*\[\s*\d+\]\s+(\S+)", line)
            if m:
                exported.add(m.group(1))
        elif mode == "import":
            m = re.match(r"\s*[0-9a-f]+\s+(?:<none>\s+)?[0-9a-f]+\s+(\S+)\s*$", line)
            if m:
                imported[dll].add(m.group(1))
    exports.setdefault(os.path.basename(path).lower(), set()).update(exported)
    imports[path] = imported

checked = 0
problems = 0
absent = collections.defaultdict(list)
for path, imported in imports.items():
    for dll, symbols in imported.items():
        if dll in exports:
            checked += len(symbols)
            missing = sorted(symbols - exports[dll])
            if missing:
                problems += 1
                print("::error::%s needs %d function(s) missing from %s: %s"
                      % (os.path.relpath(path, root), len(missing), dll, ", ".join(missing[:5])))
        elif dll.startswith(("qt6", "lib", "qlcplus")):
            absent[dll].append(os.path.relpath(path, root))

for dll, users in absent.items():
    print("::warning::%s is not shipped, wanted by %s" % (dll, ", ".join(users[:3])))

print("%d binaries, %d imported functions checked, %d problem(s)" % (len(binaries), checked, problems))
if checked < 1000:
    print("::error::too few functions checked: the import tables were not read")
    sys.exit(1)
sys.exit(1 if problems else 0)
