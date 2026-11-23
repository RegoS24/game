"""Regression: blocked enemies must not freeze at their unblocked standoff range."""
from pathlib import Path

source = (Path(__file__).resolve().parents[1] / "scripts" / "enemy.gd").read_text(encoding="utf-8")
assert "var standoff: float=0.0 if blocked else reach*0.81" in source
assert "var step: float=minf(speed*dt,maxf(0.0,distance-standoff))" in source
assert "Cover.nearest_unblocked_flank" in source
assert "elif distance>reach*0.86 or blocked:" in source
print("BLACK_SIGNAL_ENEMY_COVER_FLANK_OK")
