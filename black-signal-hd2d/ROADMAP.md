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
- v0.7.6: raster stability work, signed APK with emulator smoke, user dissatisfaction with animation unresolved.
- v0.8.0: first objective-based level with terminal interaction, enemy gate, exfil and best-time save; CI + emulator passed.
- v0.8.1: actual world-coordinate cover collisions, cover-aware hitscan and enemy obstacle flanking; awaiting device evaluation.

- 2026-11-21: enemy sentry patrol now uses the same swept circle/cover movement as pursuit (previously modified `p.y` directly and could pass through crates). Added headless assertions for patrol cover separation, pursuit distance reduction, and facing toward player. CI pending at time of update; physical-device visual review and authored directional animation remain blockers.

- 2026-11-21: Rin locomotion footfall phase now uses collision-resolved world displacement instead of unimpeded requested velocity; blocked movement no longer drives walk/run animation. Added smoke assertions for blocked versus free cover movement. GitHub Actions and Android device verification pending; this does not replace authored directional pose/rig work.
