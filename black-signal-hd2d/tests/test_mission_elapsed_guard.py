"""Static regression for mission completion-time validation.

Run: python3 tests/test_mission_elapsed_guard.py
"""
from pathlib import Path

source = (Path(__file__).resolve().parents[1] / "scripts" / "mission.gd").read_text()
guard = "if phase==Phase.EXTRACT and (not is_finite(elapsed) or elapsed<0.0):return \"\""
assert guard in source, "Extraction must reject NaN, Infinity and negative elapsed times"
assert source.index(guard) < source.index("completed_runs+=1"), "Guard must precede record mutation"
print("Mission elapsed guard: OK")
