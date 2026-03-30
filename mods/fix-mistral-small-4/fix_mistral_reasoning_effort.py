#!/usr/bin/env python3
from pathlib import Path
import sys

path = Path("/usr/local/lib/python3.12/dist-packages/vllm/tokenizers/mistral.py")

if not path.exists():
    print(f"[fix-mistral-reasoning-effort] File not found: {path}", file=sys.stderr)
    sys.exit(1)

content = path.read_text()

# Cas 1: code original observé dans le forum
old_original = (
    '        if self.version >= 15:\n'
    '            version_kwargs["reasoning_effort"] = kwargs.get("reasoning_effort")'
)

# Cas 2: workaround forum déjà appliqué mais incomplet
old_forum_patch = (
    '        if self.version >= 15:\n'
    '            _re = kwargs.get("reasoning_effort")\n'
    '            if _re is not None:\n'
    '                try:\n'
    '                    from mistral_common.protocol.instruct.messages import REASONING_EFFORTS\n'
    '                    version_kwargs["reasoning_effort"] = _re\n'
    '                except (ImportError, AttributeError):\n'
    '                    pass'
)

# Fix réellement utile:
# - on consomme la clé avec pop()
# - on ne réinjecte que si le support est présent
new_block = (
    '        if self.version >= 15:\n'
    '            _re = kwargs.pop("reasoning_effort", None)\n'
    '            if _re is not None:\n'
    '                try:\n'
    '                    from mistral_common.protocol.instruct.messages import REASONING_EFFORTS\n'
    '                    version_kwargs["reasoning_effort"] = _re\n'
    '                except (ImportError, AttributeError):\n'
    '                    pass'
)

# Déjà patché correctement
if new_block in content:
    print("[fix-mistral-reasoning-effort] Already patched")
    sys.exit(0)

if old_original in content:
    content = content.replace(old_original, new_block)
    path.write_text(content)
    print("[fix-mistral-reasoning-effort] Patched from original block")
    sys.exit(0)

if old_forum_patch in content:
    content = content.replace(old_forum_patch, new_block)
    path.write_text(content)
    print("[fix-mistral-reasoning-effort] Replaced incomplete forum workaround")
    sys.exit(0)

# Fallback plus permissif si la ligne exacte a légèrement bougé
needle = 'version_kwargs["reasoning_effort"] = kwargs.get("reasoning_effort")'
if needle in content:
    content = content.replace(
        needle,
        '_re = kwargs.pop("reasoning_effort", None)\n'
        '            if _re is not None:\n'
        '                try:\n'
        '                    from mistral_common.protocol.instruct.messages import REASONING_EFFORTS\n'
        '                    version_kwargs["reasoning_effort"] = _re\n'
        '                except (ImportError, AttributeError):\n'
        '                    pass'
    )
    path.write_text(content)
    print("[fix-mistral-reasoning-effort] Patched via fallback replacement")
    sys.exit(0)

print("[fix-mistral-reasoning-effort] Pattern not found", file=sys.stderr)
sys.exit(1)
