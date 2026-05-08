#!/usr/bin/env python3
"""Regenerate cgmanifest.json from Dockerfile + sysroots/*/deps.

Two sources:
  1. Dockerfile ADD lines (from-source tarballs and git pins)
  2. sysroots/*/deps and pkg/*/deps (Azure Linux RPMs composed into shipped
     sysroots) -- looked up against pkg/Tools/azurelinux-pkgs.json

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
PKGS_SNAPSHOT = ROOT / "pkg" / "Tools" / "azurelinux-pkgs.json"

SKIP_RPMS = {"filesystem"}  # see refresh-azurelinux-pkgs.py

# License metadata for the from-source components fetched by Dockerfile ADD
# lines. Required because ClearlyDefined does not have data for every commit
# we pin -- without this, CG raises "Missing legal information" alerts.
# Keyed by component name (tarball name or final segment of git URL).
LICENSES = {
    "binutils": "GPL-3.0-or-later",
    "config": "GPL-3.0-or-later WITH Autoconf-exception-3.0",
    "gcc": "GPL-3.0-or-later WITH GCC-exception-3.1",
    "gmp": "LGPL-3.0-or-later",
    "linux-headers": "GPL-2.0-only",
    "linux": "GPL-2.0-only",
    "llvm-project": "Apache-2.0 WITH LLVM-exception",
    "mpc": "LGPL-3.0-or-later",
    "mpfr": "LGPL-3.0-or-later",
    "musl-cross-make": "MIT",
    "musl": "MIT",
    "openssl": "Apache-2.0",
    "symcrypt": "MIT",
}


def _reg(component, name):
    """Wrap a component dict in a registration, attaching license metadata."""
    out = {"component": component}
    if name in LICENSES:
        out["license"] = LICENSES[name]
    else:
        sys.exit(f"gen-cgmanifest: missing LICENSES entry for {name!r}; "
                 f"add it to pkg/Tools/gen-cgmanifest.py.")
    return out


def from_dockerfile():
    text = re.sub(r"\\\r?\n\s*", " ", (ROOT / "Dockerfile").read_text())
    regs = []
    for m in re.finditer(r"^\s*ADD\s+(.+)$", text, re.M):
        rest = m.group(1)
        if g := re.search(r"(https?://\S+?)\.git#([0-9a-f]{40})\b", rest):
            name = g.group(1).rsplit("/", 1)[-1]
            regs.append(_reg({"type": "git", "git": {
                "repositoryUrl": g.group(1), "commitHash": g.group(2)}}, name))
        elif (c := re.search(r"--checksum=sha256:([0-9a-f]{64})", rest)) and \
             (u := re.search(r"https?://\S+", rest)):
            url = u.group(0)
            fname = url.rsplit("/", 1)[-1].split("?")[0]
            nv = re.match(r"(.+?)-(\d[\w.-]*)\.tar\.\w+$", fname)
            if nv:
                name, version = nv.group(1), nv.group(2)
            elif gw := re.search(r"\bp=([\w.-]+?)\.git\b.*?\bhb=([0-9a-f]+)", url):
                name, version = gw.group(1), f"rev{gw.group(2)}"
            else:
                name, version = (fname or "unknown", "0")
            regs.append(_reg({"type": "other", "other": {
                "name": name, "version": version,
                "downloadUrl": url, "hash": c.group(1)}}, name))
        elif re.search(r"https?://\S+", rest):
            sys.exit(f"gen-cgmanifest: unrecognized remote ADD line (needs "
                     f"--checksum=sha256:<64-hex> or <git-url>.git#<40-hex>):\n  ADD {rest}")
    return regs


def from_deps_files():
    snapshot = json.loads(PKGS_SNAPSHOT.read_text())
    pkgs = snapshot["packages"]
    wanted = set()
    for p in list(ROOT.glob("sysroots/*/deps")) + list(ROOT.glob("pkg/*/deps")):
        for line in p.read_text().splitlines():
            line = line.split("#", 1)[0].strip()
            if not line or "=" in line or line.startswith("pkg/"):
                continue
            if line in SKIP_RPMS:
                continue
            wanted.add(line)
    missing = sorted(wanted - set(pkgs))
    if missing:
        sys.exit(f"gen-cgmanifest: package(s) {missing} referenced from deps "
                 f"files but not in {PKGS_SNAPSHOT.name}; "
                 f"rerun pkg/Tools/refresh-azurelinux-pkgs.py and commit.")
    return [pkgs[name] for name in sorted(wanted)]


def main():
    regs = from_dockerfile() + from_deps_files()
    out = json.dumps({
        "$schema": "https://json.schemastore.org/component-detection-manifest.json",
        "version": 1, "registrations": regs}, indent=2) + "\n"

    if "--check" in sys.argv[1:]:
        if not MANIFEST.exists() or MANIFEST.read_text() != out:
            sys.exit(f"{MANIFEST.name} is out of sync; "
                     f"rerun pkg/Tools/gen-cgmanifest.py and commit the result.")
        print(f"{MANIFEST.name} is up to date ({len(regs)} components).")
    else:
        MANIFEST.write_text(out)
        print(f"Wrote {MANIFEST.name} ({len(regs)} components).")


if __name__ == "__main__":
    main()
