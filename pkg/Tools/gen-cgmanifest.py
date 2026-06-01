#!/usr/bin/env python3
"""Regenerate cgmanifest.json from Dockerfile ADD lines.

Each remote ADD line maps to one cgmanifest registration. For sources we
mirror via our own GitHub Release, the actual `ADD` URL points at the
mirror but Component Governance needs to see the *canonical upstream* so
that license and CVE matching work correctly. To handle that, prefix any
mirrored ADD with a `# upstream: <url>` comment on its own line; the URL
in that comment becomes the cgmanifest `downloadUrl` (the bytes are still
sha256-pinned by the ADD itself, so the substitution is safe). ADDs
without an `# upstream:` comment use their own URL as before.

To avoid silent CG-matching degradation, an ADD that fetches from our
mirror namespace (`MIRROR_URL_PREFIX` below) MUST declare `# upstream:`;
the script errors out otherwise.

Explicit license assignments (TARBALL_LICENSES, GIT_LICENSES) are
attached to known components so that CG / ClearlyDefined misses don't
trigger "Missing legal information" review cycles.

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

MIRROR_URL_PREFIX = "https://github.com/microsoft/openvmm-deps/releases/download/"

# SPDX license expressions for our pinned tarballs, keyed by sha256. Hashes
# uniquely identify the bytes, so this binding is stable across any URL
# changes (mirror swaps, version bumps require updating both hash and entry).
TARBALL_LICENSES = {
    "ab66fc2d1c3ec0359b8e08843c9f33b63e8707efdff5e4cc5c200eae24722cbf": "GPL-3.0-or-later",                                   # binutils-2.33.1
    "75d5d255a2a273b6e651f82eecfabf6cbcd8eaeae70e86b417384c8f4a58d8d3": "GPL-3.0-or-later WITH Autoconf-exception-generic",   # config.sub
    "a6e21868ead545cf87f0c01f84276e4b5281d672098591c1c896241f09363478": "GPL-3.0-or-later WITH GCC-exception-3.1",            # gcc-11.5.0
    "5275bb04f4863a13516b2f39392ac5e272f5e1bb8057b18aec1c9b79d73d8fb2": "LGPL-3.0-or-later OR GPL-2.0-or-later",              # gmp-6.1.2
    "dc7abf734487553644258a3822cfd429d74656749e309f2b25f09f4282e05588": "GPL-2.0-only WITH Linux-syscall-note",               # linux-headers-4.19.88-2
    "6985c538143c1208dcb1ac42cedad6ff52e267b47e5f970183a3e75125b43c2e": "LGPL-3.0-or-later",                                   # mpc-1.1.0
    "c05e3f02d09e0e9019384cdd58e0f19c64e6db1fd6f5ecf77b4b1c61ca253acc": "LGPL-3.0-or-later",                                   # mpfr-4.0.2
    "a9a118bbe84d8764da0ea0d28b3ab3fae8477fc7e4085d90102b8596fc7c75e4": "MIT",                                                 # musl-1.2.5
    "e14cf2b94492c3e925f0070ba7fdfedeb2048c91eea9c5a5afb30232a3976331": "BSD-3-Clause",                                         # virtio-win-0.1.285
}

# SPDX license expressions for git-cloned components keyed by repository URL.
# Used when ClearlyDefined doesn't have data for the pinned commit, or when
# we want to avoid a CD round-trip on every CG run.
GIT_LICENSES = {
    "https://github.com/llvm/llvm-project": "Apache-2.0 WITH LLVM-exception",
}

text = ""
for dockerfile in ["Dockerfile", "Dockerfile.virtio-win"]:
    p = ROOT / dockerfile
    if p.exists():
        text += re.sub(r"\\\r?\n\s*", " ", p.read_text()) + "\n"

regs = []
upstream = None  # set by a `# upstream: <url>` comment, consumed by the next ADD
for line in text.splitlines():
    s = line.strip()
    if m := re.match(r"#\s*upstream:\s*(\S+)\s*$", s):
        upstream = m.group(1)
        continue
    if not s.startswith("ADD "):
        # Any non-blank, non-comment line between an `# upstream:` and an ADD
        # invalidates the override so it can't silently bind to a far-away ADD.
        if s and not s.startswith("#"):
            upstream = None
        continue

    rest = s[4:]
    if g := re.search(r"(https?://\S+?)\.git#([0-9a-f]{40})\b", rest):
        reg = {"component": {"type": "git", "git": {
            "repositoryUrl": g.group(1), "commitHash": g.group(2)}}}
        if lic := GIT_LICENSES.get(g.group(1)):
            reg["license"] = lic
        regs.append(reg)
    elif (c := re.search(r"--checksum=sha256:([0-9a-f]{64})", rest)) and \
         (u := re.search(r"https?://\S+", rest)):
        sha = c.group(1)
        if u.group(0).startswith(MIRROR_URL_PREFIX) and upstream is None:
            sys.exit(f"gen-cgmanifest: ADD fetches from the openvmm-deps mirror "
                     f"({MIRROR_URL_PREFIX}...) but is missing a preceding "
                     f"`# upstream: <canonical-url>` comment. Without it the "
                     f"cgmanifest entry would point at the mirror instead of "
                     f"the canonical upstream, degrading Component Governance "
                     f"license/CVE matching.\n  ADD {rest}")
        url = upstream or u.group(0)
        fname = url.rsplit("/", 1)[-1].split("?")[0]
        nv = re.match(r"(.+?)-(\d[\w.-]*)\.(?:tar\.\w+|iso)$", fname)
        name, version = (nv.group(1), nv.group(2)) if nv else (fname or "unknown", "0")
        reg = {"component": {"type": "other", "other": {
            "name": name, "version": version,
            "downloadUrl": url, "hash": sha}}}
        if lic := TARBALL_LICENSES.get(sha):
            reg["license"] = lic
        regs.append(reg)
    elif re.search(r"https?://\S+", rest):
        sys.exit(f"gen-cgmanifest: unrecognized remote ADD line (needs "
                 f"--checksum=sha256:<64-hex> or <git-url>.git#<40-hex>):\n  ADD {rest}")
    upstream = None  # consumed (or not applicable to this ADD type)

out = json.dumps({
    "$schema": "https://json.schemastore.org/component-detection-manifest.json",
    "version": 1, "registrations": regs}, indent=2) + "\n"

if "--check" in sys.argv[1:]:
    if not MANIFEST.exists() or MANIFEST.read_text() != out:
        sys.exit(f"{MANIFEST.name} is out of sync with Dockerfiles; "
                 f"rerun pkg/Tools/gen-cgmanifest.py and commit the result.")
    print(f"{MANIFEST.name} is up to date ({len(regs)} components).")
else:
    MANIFEST.write_text(out)
    print(f"Wrote {MANIFEST.name} ({len(regs)} components).")
