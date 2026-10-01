#!/usr/bin/env bash
# Prints every version of hexx listed by the registry index (yanked ones excluded), in index
# order (oldest first), one per line.
set -euo pipefail
curl -fsS https://scarbs.xyz/api/v1/index/he/xx/hexx.json |
  python3 -c 'import json,sys; [print(e["v"]) for e in json.load(sys.stdin) if not e.get("yanked")]'
