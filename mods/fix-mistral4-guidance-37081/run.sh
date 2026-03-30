#!/bin/bash
set -euo pipefail

SITE_PACKAGES="/usr/local/lib/python3.12/dist-packages"
PR_URL="https://patch-diff.githubusercontent.com/raw/vllm-project/vllm/pull/37081.diff"
MARKER_FILE="$SITE_PACKAGES/vllm/tool_parsers/mistral_tool_parser.py"
MARKER_STRING="def should_apply_mistral_grammar("

echo "[fix-mistral4-guidance-37081] Starting..."

if [ ! -d "$SITE_PACKAGES/vllm" ]; then
    echo "[fix-mistral4-guidance-37081] Error: vllm package not found in $SITE_PACKAGES"
    exit 1
fi

if [ -f "$MARKER_FILE" ] && grep -q "$MARKER_STRING" "$MARKER_FILE"; then
    echo "[fix-mistral4-guidance-37081] Patch already present, skipping."
    exit 0
fi

TMP_DIFF="/tmp/pr37081.diff"
FILTERED_DIFF="/tmp/pr37081.runtime.diff"

cleanup() {
    rm -f "$TMP_DIFF" "$FILTERED_DIFF"
}
trap cleanup EXIT

echo "[fix-mistral4-guidance-37081] Downloading PR diff..."
curl -fsSL "$PR_URL" -o "$TMP_DIFF"

echo "[fix-mistral4-guidance-37081] Filtering runtime files..."
python3 - "$TMP_DIFF" "$FILTERED_DIFF" <<'PY'
import sys

src = sys.argv[1]
dst = sys.argv[2]
allowed = {
    "vllm/entrypoints/openai/chat_completion/serving.py",
    "vllm/entrypoints/openai/engine/serving.py",
    "vllm/entrypoints/serve/render/serving.py",
    "vllm/sampling_params.py",
    "vllm/tokenizers/mistral.py",
    "vllm/tool_parsers/mistral_tool_parser.py",
    "vllm/v1/structured_output/backend_guidance.py",
    "vllm/v1/structured_output/backend_types.py",
    "vllm/v1/structured_output/backend_xgrammar.py",
}

with open(src, "r", encoding="utf-8") as f:
    lines = f.readlines()

chunks = []
current = []
keep = False

def validate_chunk(chunk_lines: list[str]) -> None:
    text = "".join(chunk_lines)
    forbidden_prefixes = (
        "rename from ",
        "rename to ",
        "new file mode ",
        "deleted file mode ",
    )
    for ln in chunk_lines:
        if ln.startswith(forbidden_prefixes):
            raise RuntimeError(f"Unsupported diff metadata in allowed file: {ln.strip()}")
    if "GIT binary patch\n" in text:
        raise RuntimeError("Binary patch detected in allowed file")
    if "\n--- /dev/null\n" in text or "\n+++ /dev/null\n" in text:
        raise RuntimeError("Add/delete file patch is not supported in this mod")

for line in lines:
    if line.startswith("diff --git "):
        if keep and current:
            validate_chunk(current)
            chunks.extend(current)
        current = [line]
        parts = line.strip().split()
        if len(parts) >= 4 and parts[2].startswith("a/"):
            path = parts[2][2:]
            keep = path in allowed
        else:
            keep = False
    else:
        if current:
            current.append(line)

if keep and current:
    validate_chunk(current)
    chunks.extend(current)

with open(dst, "w", encoding="utf-8") as f:
    f.writelines(chunks)
PY

if [ ! -s "$FILTERED_DIFF" ]; then
    echo "[fix-mistral4-guidance-37081] Error: filtered diff is empty."
    exit 1
fi

if ! grep -q '^diff --git ' "$FILTERED_DIFF"; then
    echo "[fix-mistral4-guidance-37081] Error: filtered diff has no patch blocks."
    exit 1
fi

echo "[fix-mistral4-guidance-37081] Validating patch..."
if patch --forward --batch --dry-run -p1 -d "$SITE_PACKAGES" < "$FILTERED_DIFF" >/dev/null 2>&1; then
    patch --forward --batch -p1 -d "$SITE_PACKAGES" < "$FILTERED_DIFF"
    echo "[fix-mistral4-guidance-37081] Applied successfully."
    exit 0
fi

if patch --reverse --batch --dry-run -p1 -d "$SITE_PACKAGES" < "$FILTERED_DIFF" >/dev/null 2>&1; then
    echo "[fix-mistral4-guidance-37081] Patch already applied (reverse check)."
    exit 0
fi

echo "[fix-mistral4-guidance-37081] Error: patch does not apply cleanly to current vLLM version."
echo "[fix-mistral4-guidance-37081] Tip: rebuild with --apply-vllm-pr 37081 or pin vllm-ref closer to PR base."
exit 1
