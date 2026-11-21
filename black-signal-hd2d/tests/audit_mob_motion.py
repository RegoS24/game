"""Full-frame directional enemy atlas audit for Android art QA.

Run after prepare_mobs.py. Structural failures stop CI; motion metrics are
diagnostics, not a claim that procedural poses are artistically correct.
"""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "assets" / "mobs"
OUT = Path(__file__).resolve().parents[1] / "artifacts" / "mob_motion_audit.json"
MOBS = ("raider", "guard", "brute", "hacker", "hound", "drone")
W, H, COLS, ROWS = 192, 224, 8, 16


def audit(name):
    path = ROOT / f"{name}_combat.webp"
    with Image.open(path) as source:
        if source.size != (W * COLS, H * ROWS) or "A" not in source.getbands():
            raise AssertionError(f"{name}: invalid atlas geometry or alpha")
        alpha = source.getchannel("A")
        frames = []
        for i in range(COLS * ROWS):
            x, y = (i % COLS) * W, (i // COLS) * H
            mask = alpha.crop((x, y, x + W, y + H)).point(
                lambda a: 255 if a > 85 else 0
            )
            box = mask.getbbox()
            if box is None:
                raise AssertionError(f"{name}: empty frame {i}")
            left, top, right, bottom = box
            if right - left < 8 or bottom - top < 12:
                raise AssertionError(f"{name}: tiny frame {i}: {box}")
            frames.append({"index": i, "bounds": list(box),
                           "center": [(left + right) / 2, (top + bottom) / 2],
                           "area": (right - left) * (bottom - top)})
    jumps = []
    for i in range(1, len(frames)):
        a, b = frames[i - 1], frames[i]
        jumps.append({"from": i - 1, "to": i,
                      "center_delta": round(sum((a["center"][k] - b["center"][k]) ** 2
                                                for k in range(2)) ** .5, 2),
                      "area_ratio": round(max(a["area"], b["area"]) /
                                          min(a["area"], b["area"]), 3)})
    return {"frames_checked": len(frames),
            "largest_center_jumps": sorted(jumps, key=lambda j: j["center_delta"],
                                           reverse=True)[:10],
            "largest_area_changes": sorted(jumps, key=lambda j: j["area_ratio"],
                                            reverse=True)[:10],
            "note": "Adjacent atlas slots can cross clip/direction boundaries; review flagged pairs manually."}


def main():
    report = {"schema": 1, "frame_size": [W, H],
              "purpose": "Art QA diagnostics; no visual-quality certification",
              "mobs": {name: audit(name) for name in MOBS}}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("BLACK_SIGNAL_FULL_MOB_ATLAS_OK", sum(
        entry["frames_checked"] for entry in report["mobs"].values()
    ))
    print("MOTION_AUDIT", OUT)


if __name__ == "__main__":
    main()
