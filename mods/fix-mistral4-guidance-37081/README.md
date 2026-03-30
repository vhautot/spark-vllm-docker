# fix-mistral4-guidance-37081

This mod ports the runtime changes from vLLM PR [#37081](https://github.com/vllm-project/vllm/pull/37081)
that improve Mistral tool-calling and reasoning handling with guidance/lark structured outputs.

## What it does

- Downloads PR `#37081` diff at runtime.
- Keeps only the targeted runtime files under `vllm/`.
- Applies the filtered patch to the installed package in:
  `/usr/local/lib/python3.12/dist-packages`.

The script is idempotent and skips when the patch appears already applied.

## Usage

```bash
./launch-cluster.sh --apply-mod mods/fix-mistral4-guidance-37081 exec vllm serve <model> ...
```

## Notes

- This mod intentionally excludes test-only files from the PR.
- If the patch does not apply cleanly (vLLM drift), rebuild with:

```bash
./build-and-copy.sh --rebuild-vllm --apply-vllm-pr 37081
```
