import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "services/api/src"))

from attendance_api.config import Settings  # noqa: E402
from attendance_api.main import create_app  # noqa: E402


target = ROOT / "contracts/openapi.json"
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(
    json.dumps(create_app(Settings(app_env="test")).openapi(), indent=2, sort_keys=True) + "\n"
)
print(target)
