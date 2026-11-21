"""Guard against unbounded checkpoint reads on memory-constrained Android devices.

This is a source-level safety assertion; the existing Godot smoke test covers
normal checkpoint round trips, while on-device corrupted-file QA is still needed.
"""
from pathlib import Path
source = (Path(__file__).resolve().parents[1] / "scripts/checkpoint.gd").read_text(encoding="utf-8")
start = source.index("static func read(")
end = source.find("\nstatic func ", start + 1)
read_body = source[start:end if end != -1 else None]
assert "file.get_length()>32768" in read_body, "Missing pre-read file-size guard"
assert read_body.index("file.get_length()>32768") < read_body.index("file.get_as_text()"), "Checkpoint is read before size check"
assert "file.close()" in read_body, "Checkpoint read must close file"
print("CHECKPOINT_PRE_READ_SIZE_GUARD_OK")
