"""Source-level guard for nonlethal enemy hit-stun and committed attacks."""
from pathlib import Path

source = (Path(__file__).resolve().parents[1] / "scripts" / "enemy.gd").read_text()
hit = source.split("func take_hit() -> bool:", 1)[1].split("func update(", 1)[0]
update = source.split("func update(", 1)[1].split("func frame_for(", 1)[0]
assert "const HIT_STUN_DURATION: float=0.18" in source
assert "var hit_stun: float = 0.0" in source
assert hit.index("if hp<=0:") < hit.index("hit_stun=HIT_STUN_DURATION")
assert "hit_stun=0.0;set_clip(DEATH)" in hit
assert "hit_stun=HIT_STUN_DURATION" in hit
assert "if clip==ATTACK and not attack_done:" in hit
assert "if hit_stun>0.0:" in update
assert "hit_stun=maxf(0.0,hit_stun-dt)" in update
assert "if clip!=ATTACK or not attack_done:" in update
assert update.index("if hit_stun>0.0:") < update.index("var movement_origin:")
assert "set_clip(IDLE)" in update.split("if hit_stun>0.0:", 1)[1].split("var movement_origin:", 1)[0]
print("BLACK_SIGNAL_ENEMY_HIT_STUN_OK")
