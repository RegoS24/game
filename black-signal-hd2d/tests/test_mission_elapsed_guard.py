"""Static regression for mission completion-time validation.

Run: python3 black-signal-hd2d/tests/test_mission_elapsed_guard.py
"""
from pathlib import Path

source = (Path(__file__).resolve().parents[1] / "scripts" / "mission.gd").read_text()
start = source.index("func interact(")
end = source.index("\nfunc objective_text(", start)
interact = source[start:end]
guard = 'if phase==Phase.EXTRACT and (not is_finite(elapsed) or elapsed<0.0):return ""'
mutation = "completed_runs=mini(completed_runs+1,2147483646)"
assert guard in interact, "Extraction must reject NaN, Infinity and negative elapsed times"
assert mutation in interact, "Completion count must use the current saturating increment"
assert interact.index(guard) < interact.index("phase=Phase.COMPLETE") < interact.index(mutation), (
    "Elapsed validation must precede completion and record mutation"
)
print("Mission elapsed guard: OK")
