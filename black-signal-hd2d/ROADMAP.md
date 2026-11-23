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

- 2026-11-23: Android background/focus-loss handler now performs only one checkpoint write when transitioning from gameplay to pause (the pause routine already persists state); redundant write on every subsequent focus-loss notification removed. Expanded headless gameplay smoke to exercise repeated focus-loss and application-pause notifications without resuming combat or mutating HP/ammo/position. Commit `1d6b8486`. Acceptance: current-head GitHub Actions Godot smoke + APK export/emulator boot pass; physical Android app-switch and storage-interruption tests still required. **CI, APK and on-device behavior unverified at commit time.** Gameplay and art unchanged; remaining blockers are authored Rin/mob poses, shimmer, campaign breadth, audio and device QA.


- 2026-11-23: Added a fast, deterministic duplicate-method regression gate for every GDScript file after the previous `_notification` collision prevented parsing. Commits `c017ba95`, `cb15f548`. CI now checks duplicate top-level `func`/`static func` declarations immediately after checkout, before downloading Godot/Android SDK. Acceptance: new push CI runs this test and subsequently completes Godot import, gameplay smoke, APK export and emulator launch. **Current CI/APK result not verified; no gameplay or artwork changed.** Priority remains approved directional Rin/mob poses, shimmer-free rendering, content, audio and physical-device QA.


- 2026-11-23: Android lifecycle protection: while gameplay is active, application pause or window focus loss now invokes the existing pause/checkpoint flow, clearing held fire/movement/touch controls and keeping gameplay paused on return. Commits `36d04d99`, `70282c20`. Added `tests/test_android_lifecycle.py` static regression guard. Acceptance: run Python regression and headless Godot smoke in CI, export Android APK, then test Home/app-switch/notification interruptions on a physical Android device. **Runtime CI, actual device lifecycle, and visual quality not yet verified.** Remaining: authored directional Rin/mob animation, shimmer, campaign content, audio and device QA.

- 2026-11-23: Checkpoint staging-file hygiene: remove failed-write `.tmp` files and clear interrupted staging files on explicit checkpoint reset. Added headless smoke assertion creating an interrupted staging file and verifying reset deletes it. Commits `dd65c50e`, `cae7d539`. Acceptance: headless Godot smoke, Android export and emulator boot succeed on this head; verify save/reset on physical Android. **CI and hardware behavior not yet verified.** No visual/animation changes. Remaining blockers: authored Rin/enemy poses, shimmer, content/audio, device QA.

- 2026-11-23: Hardened Chapter 01 checkpoint restoration: enemy HP must not exceed the corresponding archetype's authored maximum (raider 3, guard 4, brute 8, hacker 3, hound 3, drone 4). Added six per-archetype invalid-save assertions to the existing headless Godot smoke. Commits `318db882` and `adf13d1b`. Acceptance: latest push Actions headless smoke, Android export and emulator boot pass; verify save/resume on physical devices. At commit time these results are **unverified**. This is save integrity work, not a graphics or gameplay-content milestone. Remaining priority: authored Rin/mob poses and shimmer review, content, audio, accessibility, Android QA.


- 2026-11-23: Added side-view sprite mirroring hysteresis (±0.12 lateral dot threshold) to prevent left/right silhouette snapping when camera and enemy heading are nearly perpendicular. Added deterministic source/threshold regression and connected it to push CI. Earlier CI run #45085632899 passed on the preceding commit. Acceptance: new regression, headless Godot and Android emulator pass, then review recorded in-game camera sweeps; physical-device shimmer remains unverified. Does not replace warped source poses or constitute visual AAA certification.


- 2026-11-22: Nonlethal enemy hits now enforce at least 0.30 s attack cooldown alongside 0.18 s hit-stun; interrupted windups retain their stronger 0.45 s recovery. This prevents an enemy with an expired cooldown from attacking immediately on stagger recovery. Updated existing source regression (already connected to push CI). Acceptance: source regression and Android CI pass, then verify retaliation timing in a real encounter. **New CI and on-device gameplay unverified.** Remaining: authored animations, visual shimmer, more levels, sound and physical-device QA.

- 2026-11-22: Nonlethal player hits now impose 0.18 s enemy hit-stun, briefly halting pursuit and uncommitted windups; already committed attacks retain their active-frame semantics and lethal hits still take priority. Added source regression to push CI. Acceptance: regression + headless Godot + Android emulator pass, then visually inspect reaction timing, animation quality and real-device responsiveness. At commit time the new CI is unverified; no new artwork or APK release claimed. Remaining: authored directional poses, hit effects/audio, content, real-device QA.\n\n
- 2026-11-22: A successful player shot during an enemy's telegraphed windup now cancels the pending strike and applies at least 0.45 s recovery; lethal hits still take precedence, and already-committed strikes cannot be retroactively cancelled. Source regression added to push CI. Acceptance: source regression, Godot smoke and Android emulator checks pass; playtest timing, enemy telegraph readability and hit reactions on hardware. Previous CI #106 passed before this change; current CI result pending. Remaining: authored directional animation poses, hit FX/sound, richer encounters and real-device tests.

- 2026-11-22: Enemy attacks now commit to their facing direction during telegraph, and damage requires the target within a 120-degree forward cone (dot >= 0.5) as well as range and clear line of sight. Players can sidestep instead of being tracked by a rotating strike sprite. Source-level regression added to push CI; Godot/Android runtime result pending. Acceptance: test passes, Android smoke passes, visually confirm attack direction and fairness. Remaining: attack animations still use warped source poses; directional rig and on-device feel tests required.

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

### 2026-11-22 — Coincident enemy separation
- Fixed combat crowd separation when two living enemies occupy exactly the same position. Previously the zero-length difference skipped the resolution entirely, leaving overlapping silhouettes and collision bodies; now a deterministic horizontal axis separates them through the existing cover-aware movement routine.
- Added headless smoke assertion for identical enemy positions, positive separation and no penetration of cover. Code commit: `c4d2a2b9d9533dc21f11010ea9095846b90b876d`.
- Acceptance: push CI headless smoke, Android export and emulator smoke succeed; verify enemies visually in a crowded encounter. This addresses coincident bodies, **not** authored 2D gait quality or shimmer.
- Remaining blockers: approved directional Rin/enemy source poses or rig, full campaign, audio/UX, real-device performance and motion capture.

### 2026-11-22 — Mission completion record integrity
- Extraction now rejects negative, NaN and infinite elapsed times before changing completion count or personal best (`9937c90`). This prevents invalid mission timing from contaminating persistent progression.
- Added source regression and push CI gate (`669b5cc`, `9810566`). Acceptance: source test and Godot smoke pass; Android export and emulator launch succeed. **CI and device results pending.**
- Blockers: authored directional Rin/mob animation source, visible shimmer, full campaign/content, sound and physical Android QA. No claim of improved visual quality from this change.

### 2026-11-22 — Validate persisted Chapter 01 mission records
- `mission.gd::load_record()` now validates the ConfigFile Variant types before conversion: invalid best times (NaN, Infinity, negative, strings) reset to the unset sentinel, and invalid completion counters (negative, non-integer, excessively large) reset to zero. This prevents malformed saved records from poisoning results/HUD state or triggering invalid conversions.
- Added `tests/test_mission_record_validation.py` and push CI gate. Commits: `7fec57d`, `343e171`, `a034282`.
- Acceptance: Python regression passes, Godot headless import/smoke succeeds, Android APK exports and emulator boots; explicitly inject corrupt ConfigFile records in emulator for end-to-end proof. **New CI and APK are not yet verified.** This is save integrity, not a visual improvement.
- Next: inspect the latest Actions result, fix any failure, then prioritize authored directional character rigs/poses and motion capture; full campaign/audio/device QA remain blocked.

### 2026-11-22 — Bound Chapter 01 replay completion counter
- Repeated successful extraction now saturates `completed_runs` at 2,147,483,646, matching the persisted-record validator's accepted range, rather than incrementing indefinitely and eventually overflowing. Source commit `488a9f6`; regression `a9e0426` extends the existing push CI gate.
- Acceptance: regression and Godot headless smoke pass, APK export and emulator launch pass, then test replay/save/reload on Android. **These execution results remain unverified at time of commit.** No new art or content is claimed.
- Priority blockers: authored directional Rin/mob poses and shimmer; deeper campaign, UX/audio, device performance and physical Android testing.

### 2026-11-22 — Missing/corrupt mission record reload
- `mission.gd::load_record()` now clears in-memory personal-best and completion counters **before** loading the ConfigFile. Missing/unreadable files previously returned early and could retain stale values from an earlier load in the same process. Commits `c97dfe3`, `93b31aa`.
- Acceptance: source regression verifies both resets precede the early return; push CI passes Godot headless smoke, Android export and emulator launch. **CI and real-device results pending.** No animation or visual quality improvement claimed.
- Next: verify Actions/artifacts, replace warped directional source poses or implement a validated 2D rig, then continue campaign, audio and performance work.

### 2026-11-22 — Staged Chapter 01 record writes
- Chapter 01 personal-best records now save to a sibling `.tmp` ConfigFile before renaming over the destination, rather than truncating the existing record during a direct write. Failed staging or rename returns failure; a failed rename removes its temporary file. Commits `9e7d8d2` and `abaa182`.
- Acceptance: source regression passes on push, Godot headless smoke and Android export pass, then test forced interruption/low-storage behavior and app restart on an Android device. **No CI, Android durability or visual-quality result claimed yet.**
- Remaining: authored Rin/mob directional rigs and shimmer, campaign depth, sound/UX, real-device performance and release QA.

### 2026-11-22 — Clean failed record staging writes
- `mission.gd::save_record()` now removes a partially written sibling `.tmp` when `ConfigFile.save()` fails; the existing cleanup on rename failure is retained. Commits `0137b7a`, `54bcb95`.
- Existing `tests/test_mission_record_validation.py` now asserts both failure paths remove the staging file before returning. Acceptance: Python regression passes in push CI, Godot headless and Android export pass, then interrupted/low-storage write behavior is verified on an actual Android device. **CI and device outcomes not yet confirmed.**
- Priority blockers unchanged: authored directional Rin/enemy animation rigs and shimmer, combat feel, mission/level depth, sound and release QA.

### 2026-11-23 — Cover-aware enemy pursuit inside attack range
- Fixed an AI standoff deadlock: when cover obstructed the player inside an enemy's normal weapon range, the enemy could request zero movement and never reach a flanking route. Blocked enemies now approach cover rather than maintaining the unobstructed firing distance; the existing cover collision and flank steering remain in effect.
- Added `tests/test_enemy_cover_flank.py` and a push-triggered workflow step. Commits `d6adb52`, `aba180c`, `7650443`.
- Acceptance: regression, headless Godot smoke, Android export and emulator launch all pass; inspect real encounters to ensure enemies do not walk through cover or oscillate near crates. **CI and physical Android results not yet verified.**
- Remaining blockers: authored Rin/enemy directional 2D rigs and shimmer, more missions/content, audio, accessibility and real-device performance QA.
