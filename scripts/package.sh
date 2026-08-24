#!/usr/bin/env bash
set -euo pipefail
version="$(awk -F': ' '/^## Version:/{print $2}' MPlusApplicationTracker/MPlusApplicationTracker.toc)"
out="dist/MPlusApplicationTracker-${version}.zip"
rm -rf dist package-root
mkdir -p package-root/MPlusApplicationTracker dist
cp MPlusApplicationTracker/*.toc MPlusApplicationTracker/*.lua package-root/MPlusApplicationTracker/
( cd package-root && zip -qr "../${out}" MPlusApplicationTracker )
unzip -t "${out}"
python3 - "${out}" <<'PY'
import sys, zipfile
path = sys.argv[1]
with zipfile.ZipFile(path) as z:
    names = z.namelist()
    assert names and all(name.startswith("MPlusApplicationTracker/") for name in names)
    assert "MPlusApplicationTracker/MPlusApplicationTracker.toc" in names
print(path)
PY
