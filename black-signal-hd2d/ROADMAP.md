# BLACK SIGNAL — production roadmap (Android HD2D)

Last reviewed 2026-11-21. This is a development project, not an AAA release. Godot 4.5.1, landscape Android.

## Quality gates and remaining work
1. **Playable Chapter 01:** boot → signal-terminal interaction → six hostile encounters → extraction → results → saved personal best. **Implemented in v0.8.0; physical-device playability unverified.**
2. **Rin fidelity and animation:** identical approved Rin throughout, natural opposite-leg footfalls, stable fur/hair and no shimmer. **Not met**. Current images rely on warp interpolation. Next create approved segmented 2D rig and visually inspect real runtime videos; adding FPS or filters isn't a cure.
3. **Combat:** responsive aiming/shooting, readable damage telegraphs, projectile feedback, enemy behavior, cover geometry, enemy flanking, fairness, gyro tests on actual Android hardware. **Partial:** v0.8.1 adds world-coordinate crate collisions, hitscan occlusion and basic mob flanking; no authored cover animations or 3D bullets.
4. **Levels:** authored locations, collisions/cover, NPCs, exploration, multiple mission archetypes, environmental storytelling. **Not met.**
5. **Progression:** persistent campaign, upgrades, save/load, pause/options, accessibility, configurable controls. **Very partial** (v0.8.0 best-run file).
6. **Production assets:** consistent 2.5D art, sound design/music, FX, authored UI, performance budgets and licensing. **Not met.**
7. **Release:** QA on multiple low/mid/high-tier Android devices, FPS/crash reports, localization, signing and store compliance. **Not met.**

## Engineering workflow
- Keep one meaningful, scoped feature per commit and maintain buildable main branch.
- Validate gameplay state changes with headless Godot tests and Android emulator boot/screenshots on every push.
- Visual quality, real phone controls and player feel require actual review; don't equate CI success with AAA quality.
- Persist verified changes in the repository and report clear limitations.

## History

- 2026-11-21: Checkpoint station IDs now reject NaN/Infinity before integer conversion; headless smoke covers non-finite, fractional and out-of-range station values. Commits d1ba096 and d7f38f9. **CI and APK validation pending**. No new art or gameplay content in this patch. Next: check CI and prioritize authored directional Rin/mob poses and visible shimmer regression review.

- 2026-11-21: Checkpoint validator now rejects fractional/non-finite HP, ammunition, kill counts, mission phase, version, and enemy kind/HP rather than truncating them with `int()`. Added headless regression cases. Commits cd2ab8d and 525d1efa; GitHub Actions and APK execution **not yet verified**. Remaining blockers: validate Android lifecycle and save recovery on hardware; improve authored character poses and remove shimmering.

- 2026-11-21: Hardened checkpoint validation against non-finite player/enemy coordinates, non-finite aim/timer values and duplicate/partial medical station IDs. Added headless smoke assertions for these corrupt-save cases. Source committed; **CI and Android runtime results not yet verified**. Remaining save blockers: full campaign slots, durable write-failure recovery and real-device lifecycle tests.


- 2026-11-21: Added versioned Chapter 01 checkpoint persistence with atomic JSON replacement, strict state validation, auto-save on pause/background and lobby resume into manual-resume pause. Stores player HP/ammo/position/aim, mission phase, elapsed time, used med stations, enemy HP and positions. Clears on victory, defeat or explicit new game; never touches personal-best or gyro settings. Headless roundtrip/corruption smoke added. Limitations: mid-animation frames, enemy cooldowns and temporary reload progress intentionally reset on restore; full campaign slots and real-device lifecycle tests remain outstanding. CI result pending.


- 2026-11-21: Android lifecycle safety: when the app backgrounds or the window loses focus, combat enters manual-resume pause and held touch/fire inputs clear; foreground return recalibrates gyro but does not auto-resume. Headless smoke now checks no HP/ammo/position/timer changes while suspended. Commit 4dec576; new CI result pending. Device lifecycle behavior still requires real-device validation.

- 2026-11-21: Added explicit in-game pause/resume control (touch and P/Escape), overlay, held-input reset, gyro recalibration on resume and headless regression asserting HP, ammo, position and mission timer remain unchanged while paused. CI and Android emulator verification pending. This is not a save/resume-from-disk feature.

- v0.7.6: raster stability work, signed APK with emulator smoke, user dissatisfaction with animation unresolved.
- v0.8.0: first objective-based level with terminal interaction, enemy gate, exfil and best-time save; CI + emulator passed.
- v0.8.1: actual world-coordinate cover collisions, cover-aware hitscan and enemy obstacle flanking; awaiting device evaluation.

- 2026-11-21: enemy sentry patrol now uses the same swept circle/cover movement as pursuit (previously modified `p.y` directly and could pass through crates). Added headless assertions for patrol cover separation, pursuit distance reduction, and facing toward player. CI pending at time of update; physical-device visual review and authored directional animation remain blockers.

- 2026-11-21: Rin locomotion footfall phase now uses collision-resolved world displacement instead of unimpeded requested velocity; blocked movement no longer drives walk/run animation. Added smoke assertions for blocked versus free cover movement. GitHub Actions and Android device verification pending; this does not replace authored directional pose/rig work.

- 2026-11-21: enemy WALK/RUN animation phase now scales with actual collision-resolved displacement, and enemies switch to IDLE when blocked; addresses running-in-place and foot sliding at crates. Source patch committed; headless Godot, CI and physical Android visual review not yet verified. Authored directional pose/rig replacement remains the priority.

- v0.9.0: Six procedural illustrated cyberpunk building families with four directional views each, embedded into 2.5D city rendering and exported APK. These are newly generated game textures based on visual references; image-generation turnarounds have not been packaged verbatim. No physically-based 3D materials or real building mesh geometry yet.
