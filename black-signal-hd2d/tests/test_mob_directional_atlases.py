"""Asset-level regression for the six mobile enemy directional atlases.

Checks geometry and sampled authored directions; does not certify animation quality.
Run after prepare_mobs.py, before Godot import.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "assets" / "mobs"
W, H = 192, 224
SAMPLES = {
    "front_idle": 0,
    "front_walk": 12,
    "front_run": 24,
    "front_attack": 36,
    "side_idle": 72,
    "side_walk": 78,
    "side_run": 84,
    "rear_walk": 102,
    "rear_run": 114,
}

def check(name: str) -> None:
    path = ROOT / f"{name}_combat.webp"
    with Image.open(path) as source:
        assert source.size == (8 * W, 16 * H), (name, "atlas dimensions", source.size)
        assert "A" in source.getbands(), (name, "missing alpha channel")
        image = source.convert("RGBA")
    for label, index in SAMPLES.items():
        x, y = index % 8 * W, index // 8 * H
        alpha = image.crop((x, y, x + W, y + H)).getchannel("A")
        bounds = alpha.point(lambda v: 255 if v > 85 else 0).getbbox()
        assert bounds is not None, (name, label, "empty silhouette")
        left, top, right, bottom = bounds
        assert right - left >= 8 and bottom - top >= 12, (name, label, "tiny silhouette", bounds)
        assert left >= 0 and top >= 0 and right <= W and bottom <= H
    print("MOB_DIRECTIONAL_ATLAS_OK", name, len(SAMPLES))

for mob in ("raider", "guard", "brute", "hacker", "hound", "drone"):
    check(mob)
print("BLACK_SIGNAL_MOB_ATLAS_SMOKE_OK")
