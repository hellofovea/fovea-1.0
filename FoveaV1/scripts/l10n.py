#!/usr/bin/env python3
"""Lists Fovea's interface strings that have no Simplified Chinese yet (Localization/README.md).

Builds the package with the compiler's -emit-localized-strings (every SwiftUI literal and every
L("…") call, with %@ / %lld as Xcode makes them), reads Localization/zh-Hans/*.strings, and prints
the missing keys by source file.

  python3 scripts/l10n.py [--module FoveaWindow] [--scratch /tmp/fovea-l10n] [--json out.json]
"""
import argparse, glob, json, os, subprocess, sys

V1 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def strings_file(path):
    out = subprocess.run(["plutil", "-convert", "json", "-o", "-", path], capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(f"{path} doesn't parse: {out.stderr.strip()}")
    return json.loads(out.stdout or "{}")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--module")
    ap.add_argument("--scratch", default="/private/tmp/fovea-l10n")
    ap.add_argument("--json")
    a = ap.parse_args()
    # Package.swift gives each target its own folder when FOVEA_L10N is set; an incremental build
    # re-lists only the files it compiles again, so earlier lists are kept.
    out_dir = os.path.join(a.scratch, "stringsdata")
    os.makedirs(out_dir, exist_ok=True)
    cmd = ["swift", "build", "--package-path", V1, "--scratch-path", os.path.join(a.scratch, "build")]
    b = subprocess.run(cmd, capture_output=True, text=True, env={**os.environ, "FOVEA_L10N": out_dir})
    if b.returncode != 0:
        print(b.stdout[-3000:], b.stderr[-3000:])
        sys.exit("build failed")
    have = {}
    for f in sorted(glob.glob(os.path.join(V1, "Localization", "zh-Hans", "*.strings"))):
        have.update(strings_file(f))
    missing, total = {}, set()
    for f in glob.glob(os.path.join(out_dir, "*", "*.stringsdata")):
        module = os.path.basename(os.path.dirname(f))
        data = json.load(open(f))
        src = data.get("source", "")
        if not os.path.exists(src):
            continue  # a file since removed
        rel = os.path.relpath(src, os.path.join(V1, "Sources"))
        if a.module and module != a.module:
            continue
        for table in data.get("tables", {}).values():
            for e in table:
                k = e["key"]
                total.add(k)
                if k not in have:
                    missing.setdefault(rel, set()).add(k)
    n = sum(len(v) for v in missing.values())
    for rel in sorted(missing):
        print(f"\n## {rel}")
        for k in sorted(missing[rel]):
            print("  " + json.dumps(k, ensure_ascii=False))
    print(f"\n{len(total)} keys{' in ' + a.module if a.module else ''}, {n} without Chinese.")
    if a.json:
        json.dump({k: sorted(v) for k, v in missing.items()}, open(a.json, "w"), ensure_ascii=False, indent=1)

if __name__ == "__main__":
    main()
