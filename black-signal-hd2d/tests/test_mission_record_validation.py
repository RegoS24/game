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
# A failed/missing save must clear stale in-memory values before early return.
assert load.index("best_seconds=-1.0") < load.index("cfg.load(SAVE_PATH)")
assert load.index("completed_runs=0") < load.index("cfg.load(SAVE_PATH)")
assert load.count("best_seconds=-1.0") == 1
assert load.count("completed_runs=0") == 1
assert "int(cfg.get_value" not in load and "float(cfg.get_value" not in load
assert load.index("typeof(raw_best)") < load.index("float(raw_best)")
assert load.index("typeof(raw_runs)") < load.index("int(raw_runs)")
assert "completed_runs=mini(completed_runs+1,2147483646)" in src, "Completion count must saturate before save to avoid integer overflow"

# Persist via a staged sibling file; never write directly over the last valid record.
save = src[src.index("func save_record() -> bool:"):src.index("\nfunc has_marker()", src.index("func save_record() -> bool:"))]
assert 'var temp_path: String=SAVE_PATH+".tmp"' in save
assert "cfg.save(temp_path)" in save
assert "cfg.save(SAVE_PATH)" not in save
assert save.index("cfg.save(temp_path)") < save.index("DirAccess.rename_absolute(")
assert "if result!=OK:" in save and "DirAccess.remove_absolute(" in save
# Both staging failures and rename failures must remove the temporary file.
save_failure = save[save.index("if cfg.save(temp_path)!=OK:"):save.index("var result: Error=DirAccess.rename_absolute(")]
assert "DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))" in save_failure
assert save_failure.index("DirAccess.remove_absolute(") < save_failure.index("return false")
rename_failure = save[save.index("if result!=OK:"):]
assert "DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))" in rename_failure
print("BLACK_SIGNAL_MISSION_RECORD_VALIDATION_OK")
