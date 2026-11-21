"""Regression guard: animated silhouettes must not be alpha-overlaid.

This static contract catches accidental reintroduction of two-pose ghosting.
It does NOT establish visual quality; emulator screenshots and device video remain required.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
for script, method in (("scripts/rin_animator.gd", "paint"), ("scripts/enemy.gd", "paint")):
    text = (root / script).read_text(encoding="utf-8")
    match = re.search(r"(?m)^func paint\([^\n]*", text)
    assert match, f"{script}: missing paint"
    body = text[match.start():].split("\nfunc ", 1)[0]
    if script.endswith("rin_animator.gd"):
        calls = re.findall(r"(?m)^\s*draw_frame\(", body)
        assert len(calls) == 1, f"Rin overlays {len(calls)} pose calls"
        assert "draw_frame(canvas,clip,frame_index(),dst,1.0)" in body
    else:
        calls = re.findall(r"(?m)^\s*draw_pose\(", body)
        assert len(calls) == 2, "enemy hit/normal branches changed; inspect manually"
        assert "prior_clip" not in body and "prior_time" not in body
print("POSE_COMPOSITING_SINGLE_SILHOUETTE_OK")
