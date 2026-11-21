"""Regression: directional motion audit must not compare unrelated atlas rows."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_mob_motion import COLS, measure_clip_jumps

frames = []
for row in range(16):
    for frame in range(COLS):
        frames.append({"center": [row * 100 + frame, 0], "area": 100})
jumps = measure_clip_jumps(frames)
assert len(jumps) == 16 * (COLS - 1)
assert all(j["to"] // COLS == j["from"] // COLS for j in jumps)
assert all(j["center_delta"] == 1.0 for j in jumps)
loops = measure_clip_jumps(frames, loop_only=True)
assert len(loops) == 16
assert all(j["from"] % COLS == COLS - 1 and j["to"] % COLS == 0 for j in loops)
assert all(j["center_delta"] == 7.0 for j in loops)
try:
    measure_clip_jumps(frames[:-1])
except ValueError:
    pass
else:
    raise AssertionError("partial atlas row was accepted")
print("BLACK_SIGNAL_MOB_MOTION_METRICS_OK")
