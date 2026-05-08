#!/usr/bin/env python3
"""Refresh pkg/Tools/azurelinux-pkgs.json from microsoft/azurelinux upstream.

Reads the package names referenced by sysroots/*/deps and pkg/*/deps,
fetches Azure Linux's own cgmanifest.json from the upstream repo, and
writes a slimmed snapshot containing only the entries we reference.

The slim snapshot is then consumed by gen-cgmanifest.py to attribute the
tdnf-installed RPMs that get composed into shipped sysroots.

Usage:
    refresh-azurelinux-pkgs.py            # write pkg/Tools/azurelinux-pkgs.json
    refresh-azurelinux-pkgs.py --check    # exit 1 if anything is missing/stale
"""
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT = ROOT / "pkg" / "Tools" / "azurelinux-pkgs.json"
UPSTREAM = "https://raw.githubusercontent.com/microsoft/azurelinux/3.0/cgmanifest.json"

# Map from binary RPM name (as it appears in deps files) to the source-package
# name registered in microsoft/azurelinux's cgmanifest. Most are 1:1; only
# subpackages need an entry here.
ALIASES = {
    "kernel-tools": "kernel",
}

# Packages we install but intentionally don't track (no OSS upstream source).
SKIP = {
    "filesystem",  # FHS directory layout, no upstream source code
}


def collect_package_names():
    names = set()
    for p in list(ROOT.glob("sysroots/*/deps")) + list(ROOT.glob("pkg/*/deps")):
        for line in p.read_text().splitlines():
            line = line.split("#", 1)[0].strip()
            if not line or "=" in line or line.startswith("pkg/"):
                continue
            names.add(line)
    return names - SKIP


def fetch_upstream():
    with urllib.request.urlopen(UPSTREAM, timeout=60) as r:
        return json.loads(r.read())


def index_by_name(cg):
    by_name = {}
    for reg in cg.get("Registrations", []) + cg.get("registrations", []):
        c = reg.get("component") or reg.get("Component") or {}
        t = (c.get("type") or c.get("Type") or "").lower()
        sub = c.get(t) or c.get(t.capitalize()) or {}
        name = sub.get("name") or sub.get("Name")
        if name:
            by_name[name.lower()] = reg
    return by_name


def normalize(reg):
    """Lowercase top-level keys to match our convention."""
    out = {"component": {}}
    c = reg.get("component") or reg.get("Component") or {}
    t = (c.get("type") or c.get("Type") or "").lower()
    out["component"]["type"] = t
    sub = c.get(t) or c.get(t.capitalize()) or {}
    out["component"][t] = {k[0].lower() + k[1:]: v for k, v in sub.items()}
    return out


def build_snapshot():
    upstream = fetch_upstream()
    by_name = index_by_name(upstream)
    wanted = collect_package_names()
    entries = {}
    missing = []
    for name in sorted(wanted):
        lookup = ALIASES.get(name, name).lower()
        reg = by_name.get(lookup)
        if not reg:
            missing.append(name)
            continue
        entries[name] = normalize(reg)
    return entries, missing


def main():
    entries, missing = build_snapshot()
    if missing:
        print(f"WARNING: {len(missing)} package(s) not found in upstream "
              f"azurelinux/cgmanifest.json: {', '.join(missing)}", file=sys.stderr)
        print("Add an entry to ALIASES or SKIP in this script.", file=sys.stderr)
        sys.exit(2)

    out = json.dumps({"_source": UPSTREAM, "packages": entries},
                     indent=2, sort_keys=True) + "\n"

    if "--check" in sys.argv[1:]:
        if not SNAPSHOT.exists() or SNAPSHOT.read_text() != out:
            sys.exit(f"{SNAPSHOT.name} is out of sync with upstream; "
                     f"rerun pkg/Tools/refresh-azurelinux-pkgs.py and commit.")
        print(f"{SNAPSHOT.name} is up to date ({len(entries)} packages).")
    else:
        SNAPSHOT.write_text(out)
        print(f"Wrote {SNAPSHOT.name} ({len(entries)} packages).")


if __name__ == "__main__":
    main()
