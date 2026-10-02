import hashlib
import json
import sys
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODEL_DIR = ROOT / "models"


def main() -> int:
    manifest = json.loads((MODEL_DIR / "manifest.json").read_text())
    for model in manifest.values():
        if not isinstance(model, dict) or "file" not in model:
            continue
        target = MODEL_DIR / model["file"]
        if not target.exists():
            print(f"Downloading {model['file']} from the pinned source")
            urllib.request.urlretrieve(model["source"], target)
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        if digest != model["sha256"]:
            target.unlink(missing_ok=True)
            raise RuntimeError(f"Checksum mismatch for {model['file']}: {digest}")
        print(f"Verified {model['file']}: {digest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
