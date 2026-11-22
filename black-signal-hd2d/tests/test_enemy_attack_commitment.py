"""Regression guard for enemy attack commitment and sidestep evasion.

Source-level guard; Godot smoke and Android emulator remain the runtime gates.
"""
from pathlib import Path
source = (Path(__file__).resolve().parents[1] / "scripts" / "enemy.gd").read_text()
attack = source.split(" if clip==ATTACK:", 1)[1].split(" if not activated:", 1)[0]
assert "heading=rel.normalized()" not in attack, "Attack must not auto-track target during windup"
assert "heading.dot(rel.normalized())>=0.5" in attack, "Committed attack must check facing cone"
assert "not blocked and facing_target" in attack, "Damage must respect cover and facing"
assert "attack_done=true" in attack, "Attack must only apply damage once"
assert "set_clip(ATTACK)" in source, "Attack initiation missing"
print("BLACK_SIGNAL_ATTACK_COMMITMENT_OK")
