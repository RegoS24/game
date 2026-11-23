"""Regression guard for Android background lifecycle safety."""
from pathlib import Path

source = (Path(__file__).resolve().parents[1] / "scripts" / "main.gd").read_text(encoding="utf-8")
start = source.index("func _notification(what: int) -> void:")
end = source.index("\nfunc ", start + 1)
handler = source[start:end]
assert "NOTIFICATION_APPLICATION_PAUSED" in handler
assert "NOTIFICATION_WM_WINDOW_FOCUS_OUT" in handler
assert 'if mode=="game":toggle_pause()' in handler
assert 'mode="paused"' in source
assert "save_checkpoint()" in source[source.index("func toggle_pause()"):source.index("\nfunc ", source.index("func toggle_pause()")+1)]
print("BLACK_SIGNAL_LIFECYCLE_STATIC_OK")
