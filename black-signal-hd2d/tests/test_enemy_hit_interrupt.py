"""Regression guard for enemy hit-stagger fairness.

Source-level contract; Godot import, gameplay smoke, and Android launch are
separate runtime gates. Do not treat this as a visual validation.
"""
from pathlib import Path

source = (Path(__file__).resolve().parents[1] / "scripts" / "enemy.gd").read_text()
hit = source.split("func take_hit() -> bool:", 1)[1].split("func update(", 1)[0]
attack = source.split(" if clip==ATTACK:", 1)[1].split(" if not activated:", 1)[0]
assert "if hp<=0:" in hit and "set_clip(DEATH);return true" in hit
assert hit.index("if hp<=0:") < hit.index("if clip==ATTACK and not attack_done:"), "Death must take priority"
assert "if clip==ATTACK and not attack_done:" in hit, "Only pending windups may be interrupted"
assert "set_clip(IDLE)" in hit and "cool=maxf(cool,0.45)" in hit, "Interrupted enemy needs recovery"
assert "attack_done=true" in attack, "Active frame must be committed exactly once"
assert "if time>=float(DURATIONS[ATTACK])*0.48 and not attack_done:" in attack
print("BLACK_SIGNAL_ENEMY_HIT_INTERRUPT_OK")
