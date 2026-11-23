"""Regression: enemy side-view mirroring must not oscillate at camera-axis zero."""
from pathlib import Path

source = (Path(__file__).resolve().parents[1] / "scripts" / "enemy.gd").read_text(encoding="utf-8")
assert "const SIDE_FLIP_DEADBAND: float=0.12" in source
assert "var last_side_right: bool=true" in source
assert "if lateral>SIDE_FLIP_DEADBAND:last_side_right=true" in source
assert "elif lateral< -SIDE_FLIP_DEADBAND:last_side_right=false" in source
assert "flip=1.0 if last_side_right==authored_right else -1.0" in source

# Model the exact two-threshold rule: jitter cannot reverse an existing pose.
def select(previous: bool, lateral: float) -> bool:
    if lateral > 0.12:
        return True
    if lateral < -0.12:
        return False
    return previous

side = True
for value in (-0.08, 0.06, -0.11, 0.09, 0.0):
    side = select(side, value)
    assert side
side = select(side, -0.2)
assert not side
for value in (0.08, -0.03, 0.11):
    side = select(side, value)
    assert not side
assert select(side, 0.2)
print("BLACK_SIGNAL_SIDE_MIRROR_STABLE_OK")
