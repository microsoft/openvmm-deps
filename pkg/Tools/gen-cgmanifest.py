#!/usr/bin/env python3
"""Regenerate cgmanifest.json from Dockerfile ADD lines.

Usage:
    gen-cgmanifest.py            # write cgmanifest.json
    gen-cgmanifest.py --check    # exit 1 if cgmanifest.json is out of sync (CI)
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
MANIFEST = ROOT / "cgmanifest.json"

text = re.sub(r"\\\r?\n\s*", " ", (ROOT / "Dockerfile").read_text())

regs = []
for m in re.finditer(r"^\s*ADD\s+(.+)$", text, re.M):
    rest = m.group(1)
    if g := re.search(r"(https?://\S+?)\.git#([0-9a-f]{40})\b", rest):
        reg = {"component": {"type": "git", "git": {
            "repositoryUrl": g.group(1), "commitHash": g.group(2)}}}
        # ClearlyDefined doesn't have license data for our pinned llvm-project
        # commit, so attach it explicitly to avoid CG "Missing legal information".
        if g.group(1).endswith("/llvm/llvm-project"):
            reg["license"] = "Apache-2.0 WITH LLVM-exception"
        regs.append(reg)
    elif (c := re.search(r"--checksum=sha256:([0-9a-f]{64})", rest)) and \
         (u := re.search(r"https?://\S+", rest)):
        fname = u.group(0).rsplit("/", 1)[-1].split("?")[0]
        nv = re.match(r"(.+?)-(\d[\w.-]*)\.tar\.\w+$", fname)
        name, version = (nv.group(1), nv.group(2)) if nv else (fname or "unknown", "0")
        regs.append({"component": {"type": "other", "other": {
            "name": name, "version": version,
            "downloadUrl": u.group(0), "hash": c.group(1)}}})
    elif re.search(r"https?://\S+", rest):
        sys.exit(f"gen-cgmanifest: unrecognized remote ADD line (needs "
                 f"--checksum=sha256:<64-hex> or <git-url>.git#<40-hex>):\n  ADD {rest}")

out = json.dumps({
    "$schema": "https://json.schemastore.org/component-detection-manifest.json",
    "version": 1, "registrations": regs}, indent=2) + "\n"

if "--check" in sys.argv[1:]:
    if not MANIFEST.exists() or MANIFEST.read_text() != out:
        sys.exit(f"{MANIFEST.name} is out of sync with Dockerfile; "
                 f"rerun pkg/Tools/gen-cgmanifest.py and commit the result.")
    print(f"{MANIFEST.name} is up to date ({len(regs)} components).")
else:
    MANIFEST.write_text(out)
    print(f"Wrote {MANIFEST.name} ({len(regs)} components).")
