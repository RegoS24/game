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

- 2026-11-22: Corrected enemy atlas motion QA: discontinuities are now measured only within 8-frame clip rows, with loop closure separately reported; cross-row comparisons previously produced misleading false positives. Added deterministic regression and wired it to push CI (aeeac3b, b976263, 5c404e7). **New CI result and APK not yet verified.** Acceptance: regression passes; audit contains 112 within-clip transitions and 16 loop closures per mob; review actual flagged art before replacing source poses. Remaining: authored directional rigs, device screenshots, full game content and performance QA.

- 2026-11-21: Added exhaustive enemy atlas audit (`tests/audit_mob_motion.py`): checks all 128 frames across six mobs (768 total), writes per-mob largest bounding-box center/area discontinuities to `artifacts/mob_motion_audit.json`, and uploads report from push CI. Commits 31254fd and 106d76c. **CI execution pending; this is a diagnostic/structural gate, not a fix for warped art or a visual quality pass.** Next: inspect the report and Android screenshots, replace visibly defective source poses with approved directional art/rig, then remeasure.

- 2026-11-21: Added a generated-asset quality gate for all six enemy directional atlases (`tests/test_mob_directional_atlases.py`): verifies expected 8x16 frame grid, alpha presence, and non-empty front/side/rear idle/walk/run/attack sample silhouettes. Wired after mob atlas generation and before Godot import in push CI (commits e588cbd, afdd820). **CI outcome pending; checks structural integrity, not smooth motion, correct anatomy, or actual visual fidelity.** Next: inspect run result, then develop authored directional 2D rig/poses and capture device comparisons.

- 2026-11-21: Bounded checkpoint reads: `checkpoint.gd` now checks `FileAccess.get_length()` against 32 KiB **before** `get_as_text()` to avoid unbounded memory allocation on damaged Android save files. Added source regression `tests/test_checkpoint_size_guard.py` and wired it into the HD2D push workflow. Commits d69b6f5, 9c407a3, 21ac8bb. **GitHub Actions execution and physical-device corrupt-save behavior not yet verified.** Next: confirm CI, test large/corrupt save on Android emulator and device, then prioritize authored 2D rig and directional source poses.

- 2026-11-21: Rin sprite renderer now draws one fully opaque animation pose per frame, eliminating simultaneous previous/current-pose silhouettes at clip boundaries (commit b088bfc). Added static regression test for Rin/enemy pose compositing and wired it to every Android workflow push (commits 0d14c67, cbede7e). **Source change only: CI execution, emulator visual comparison, and physical Android verification still pending.** This does not repair warped source poses, missing directional Rin artwork, or footfall quality. Next: verify CI, review captured gameplay frames and replace warped source animations with authored directional poses/2D rig.

- 2026-11-21: Removed enemy pose-to-pose alpha crossfade in `scripts/enemy.gd` (commit `987c1c5`). Rendering now uses exactly one atlas pose per frame instead of overlaying two different silhouettes, which could cause ghost limbs/shimmer on mobile. Locomotion phase carry and directional selection remain unchanged. **Source committed; CI, emulator screenshot comparison and physical Android visual validation pending.** This does not solve warped/generated source poses, Rin's animation, or all shimmer. Next: inspect emulator screenshots and replace warped source poses with authored directional animation/rig.


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

### 2026-11-22 — CI failure triage (run #70)
- Confirmed failing step: Generate and validate animation atlases; audit raised `raider: empty frame 126` before Godot import and APK export.
- Root cause: `prepare_mobs.py` intentionally fills 126 of 128 texture cells (72 front + 30 side + 24 rear); indices 126 and 127 are transparent padding, not authored poses.
- Updated audit to inspect 126 populated frames and compare actual 21 six-frame clips rather than eight-column texture rows; updated metric regression for clip boundaries and loop closures.
- Acceptance: motion regression passes, all six generated atlases pass 126-frame audit, Godot smoke and Android export complete, then review actual motion captures. CI results for these commits pending.
- Blockers: no new verified APK; visual quality and physical-device validation outstanding; original pose/rig quality remains unresolved.

### 2026-11-22 — Enemy locomotion phase boundary
- Fixed a negative animation-phase wrap in `scripts/enemy.gd`: when WALK/RUN starts at time zero and actual movement is slower than requested (cover or short steps), subtracting unused frame time could send the phase below zero; the subsequent modulo jumped to the last animation frame. Phase now clamps at zero before wrapping, preventing this specific source of footfall popping.
- Source patch: `28f0c623525ee2003a6b01beb9b57016af6732fb`. **Not yet validated by a completed new CI run, APK or physical Android motion capture.**
- Acceptance: headless movement tests pass, Android build passes, then visually compare first steps and slow obstacle movement at 30/60 FPS; do not claim this repairs authored poses or texture shimmer.
- Blockers: verify latest Actions run after prior #70 atlas failure, improve authored directional Rin/enemy art, complete campaign/UX/audio and real-device performance QA.

### 2026-11-22 — Correct CI expected populated enemy frames
- Fixed a deterministic CI mismatch in `.github/workflows/black-signal-hd2d.yml`: the updated atlas auditor validates **126 authored frames per mob × 6 mobs = 756**, while the workflow still grepped for the obsolete `768` marker. This would fail the job even if the auditor passed.
- Commit: `1972ffd00051b7d23ba3971ebe63d53467d16663`. Acceptance: atlas generation and audit print `BLACK_SIGNAL_FULL_MOB_ATLAS_OK 756`, then headless smoke, signed APK export, emulator launch and screenshot artifacts all succeed in the same workflow run.
- Status: source/workflow consistency verified by reading both files; fresh Actions result, Android APK and actual device visuals **not yet verified**. No claims of animation-quality improvement. Next: inspect CI outcome before replacing authored directional sprites and expanding gameplay.

### 2026-11-22 — Release hygiene and build cadence
- Push-triggered CI still runs atlas checks, Godot smoke, APK export/signature validation and Android emulator boot, and uploads the APK and screenshots as run artifacts. It no longer publishes a new GitHub Release for every code or documentation change; release publication is restricted to intentional `workflow_dispatch` runs (commit `345fc80d37600d6ffd75a6aa3676ef13405366d3`).
- Acceptance: a push run finishes and exposes downloadable `BLACK-SIGNAL-HD2D-APK` artifact but does not create a release; a manually dispatched successful run creates a prerelease after emulator verification. Both must be verified in GitHub Actions; the current connector does not expose push-run status, so no success is claimed.
- Blockers: inspect latest Actions logs and emulator screenshots; remove misleading stale promotional release-note claims; improve authored Rin/enemy directional poses and complete gameplay, accessibility, sound and real-device QA.
