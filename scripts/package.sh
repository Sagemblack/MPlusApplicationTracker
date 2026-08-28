#!/usr/bin/env bash
set -euo pipefail
version="$(awk -F': ' '/^## Version:/{print $2}' QueueSimulator/QueueSimulator.toc)"
out="dist/QueueSimulator-${version}.zip"
rm -rf dist package-root
mkdir -p package-root/QueueSimulator dist
cp QueueSimulator/*.toc QueueSimulator/*.lua package-root/QueueSimulator/
( cd package-root && zip -qr "../${out}" QueueSimulator )
unzip -t "${out}"
python3 - "${out}" <<'PY'
import sys, zipfile
path = sys.argv[1]
with zipfile.ZipFile(path) as z:
    names = z.namelist()
    assert names and all(name.startswith("QueueSimulator/") for name in names)
    assert "QueueSimulator/QueueSimulator.toc" in names
print(path)
PY
