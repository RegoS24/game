# BLACK SIGNAL — production roadmap (Android HD2D)

Last reviewed 2026-11-21. This is a development project, not an AAA release. Godot 4.5.1, landscape Android.

## Quality gates and remaining work
1. **Playable Chapter 01:** boot → signal-terminal interaction → six hostile encounters → extraction → results → saved personal best. **Implemented in v0.8.0; physical-device playability unverified.**
2. **Rin fidelity and animation:** identical approved Rin throughout, natural opposite-leg footfalls, stable fur/hair and no shimmer. **Not met**. Current images rely on warp interpolation. Next create approved segmented 2D rig and visually inspect real runtime videos; adding FPS or filters isn't a cure.
3. **Combat:** responsive aiming/shooting, readable damage telegraphs, projectile feedback, enemy behavior, meaningful cover and fairness, gyro tests on actual Android hardware. **Partial.**
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
- v0.8.0: first objective-based level with terminal interaction, enemy gate, exfil and best-time save (awaiting CI/device assessment).
