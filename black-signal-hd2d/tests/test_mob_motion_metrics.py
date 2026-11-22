"""Regression: six-frame authored clips must not be confused with 8-column atlas rows."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_mob_motion import CLIP_LENGTH, FRAME_COUNT, measure_clip_jumps

frames = []
for clip in range(FRAME_COUNT // CLIP_LENGTH):
    for frame in range(CLIP_LENGTH):
        frames.append({"center": [clip * 100 + frame, 0], "area": 100})
assert len(frames) == 126
jumps = measure_clip_jumps(frames)
assert len(jumps) == 21 * 5
assert all(j["to"] // CLIP_LENGTH == j["from"] // CLIP_LENGTH for j in jumps)
assert all(j["center_delta"] == 1.0 for j in jumps)
loops = measure_clip_jumps(frames, loop_only=True)
assert len(loops) == 21
assert all(j["from"] % CLIP_LENGTH == 5 and j["to"] % CLIP_LENGTH == 0 for j in loops)
assert all(j["center_delta"] == 5.0 for j in loops)
try:
    measure_clip_jumps(frames[:-1])
except ValueError:
    pass
else:
    raise AssertionError("partial six-frame clip was accepted")
print("BLACK_SIGNAL_MOB_MOTION_METRICS_OK")
