#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLT_FRAMEWORKS="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
CLT_USRLIB="/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

if [ -d "$CLT_FRAMEWORKS" ]; then
    swift test --package-path "$ROOT_DIR" \
        -Xswiftc -F -Xswiftc "$CLT_FRAMEWORKS" \
        -Xlinker -F -Xlinker "$CLT_FRAMEWORKS" \
        -Xlinker -rpath -Xlinker "$CLT_FRAMEWORKS" \
        -Xlinker -rpath -Xlinker "$CLT_USRLIB" \
        "$@"
else
    swift test --package-path "$ROOT_DIR" "$@"
fi
