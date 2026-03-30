#!/bin/bash
set -euo pipefail

MOD_DIR="$(dirname "$0")"

python3 "$MOD_DIR/fix_mistral_reasoning_effort.py"
echo "[fix-mistral-reasoning-effort] Done."
