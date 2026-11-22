"""Regression for untrusted mission record values (no unsafe Variant conversion)."""
from pathlib import Path

src = (Path(__file__).resolve().parents[1] / "scripts" / "mission.gd").read_text()
start = src.index("func load_record() -> void:")
end = src.index("\nfunc save_record()", start)
load = src[start:end]
for token in (
    "best_seconds=-1.0",
    "completed_runs=0",
    "typeof(raw_best)==TYPE_FLOAT or typeof(raw_best)==TYPE_INT",
    "is_finite(candidate) and candidate>=0.0",
    "typeof(raw_runs)==TYPE_INT",
    "raw_runs>=0 and raw_runs<2147483647",
):
    assert token in load, f"Missing mission record validation: {token}"
assert "int(cfg.get_value" not in load and "float(cfg.get_value" not in load
assert load.index("typeof(raw_best)") < load.index("float(raw_best)")
assert load.index("typeof(raw_runs)") < load.index("int(raw_runs)")
print("BLACK_SIGNAL_MISSION_RECORD_VALIDATION_OK")
