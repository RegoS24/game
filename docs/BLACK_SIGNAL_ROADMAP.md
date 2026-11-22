# BLACK SIGNAL — Android delivery roadmap

Status: planning baseline (2026-11-21). AAA is an aspiration, not a verified quality claim. Preserve the existing engine, Android target, third-person game concept, Rin's canonical design, and enemies' pursuit direction.

## Definition of done for each increment
- Gameplay behavior is reproducibly tested (automated tests where practical).
- Android build succeeds in GitHub Actions, with downloadable APK and recorded SHA-256.
- Device smoke test records hardware, Android version, touch and gyro behavior, frame pacing, memory, crashes, screenshots and video; absent evidence means **not verified**.
- No noisy sprite interpolation or FPS-only workaround for missing poses. Use authored directional poses / consistent 2D rigs; check foot contact, silhouette, antialiasing and no shimmer.
- Document remaining blockers and link the implementing commit.

## Priority milestones
1. **Baseline audit**: inventory engine, source tree, CI, APK artifacts, test harness and known issues. Capture reproducible failures and device evidence.
2. **Player controller**: reliable third-person touch controls, adjustable aim-down, optional gyroscope with calibration and fallback; responsive camera, aiming and animation transitions.
3. **Combat and enemy AI**: mobs navigate *toward* player, line-of-sight, obstacle handling, hit detection, damage, readable telegraphs, spawn pacing, difficulty, regression tests.
4. **Character art/animation**: canonical Rin and enemy sheets, complete movement/action poses or 2D rig, correct orientation, smooth pose timing without artificial smearing; visual QA on Android.
5. **Game loop**: objectives, combat rewards, exploration, fail/retry, progression and balanced encounters.
6. **Content**: authored levels, traversal, encounters, quests, story beats, enemy variety and bosses.
7. **Player experience**: menu, HUD, settings, save/load, accessibility, localization, audio/music, VFX and onboarding.
8. **Android performance**: representative low/mid/high devices, thermal/battery profiling, memory and frame pacing budgets, stability soak tests.
9. **Release gates**: permissions/privacy, licensing, signing and secure secret handling, Play requirements, store assets, crash reporting, release candidate and acceptance testing.

## Open blockers (unverified until measured)
- Current branch source and exact engine implementation require inventory.
- CI build/APK status and on-device test evidence not yet established.
- User-reported: sideways mobs, enemies moving away from player, aim unable to pitch down, low-detail character rendering, unnatural 2D motion/shimmer.

## Verified baseline and current blockers (2026-11-21)
- Last completed baseline CI run #30 passed Godot import, headless smoke, APK signing/export and Android emulator launch; APK is a **development build**, not release-quality validation.
- Current iteration adds three explicit, single-use medical stations (35 HP each, capped at 100) with an interaction prompt, consumed state and restart reset. Headless regression is now required by CI; pending result is **not yet verified**.
- Open: visual art fidelity, source-authored animation/rig and shimmer, physical-device controls and performance, richer level design and narrative, accessible HUD and campaign save slots.

## Progress log
- 2026-11-21: Implemented field medical stations and medical smoke test; CI workflow now requires `BLACK_SIGNAL_MEDICAL_SMOKE_OK`. Await CI evidence before claiming APK validation.
- 2026-11-21: Created quality-gated roadmap. This documentation change is **not** a gameplay fix, APK build, or visual validation.

- 2026-11-21 (CI recovery): Run #38 (commit 89adc46) failed at **Native HD2D smoke test**, before Android export. No new APK can be claimed from it. Checkpoint regression now reports write/read failures and identifies the exact mismatched field; comparison normalizes JSON numeric types. Fixes: 031232d, b286a7c. **Pending**: confirm the next workflow reaches export and emulator; inspect smoke logs if it fails. Last published confirmed development APK remains #34. This is a test-diagnostics increment, not proof of restored save/load or improved art.

- 2026-11-22 (CI recovery): Run #117 failed in `Native HD2D smoke test` at `scripts/main.gd:893`, before Android export. The test forced `cool=0` immediately after a nonlethal hit but did not clear the new 0.18s hit-stun, so its immediate `ATTACK` expectation contradicted live combat behavior. Commit `81c40e9` now asserts the post-hit stun/recovery gate and advances 24 simulation ticks before verifying the subsequent attack. **Pending:** verify the new workflow reaches APK export and emulator; do not claim an updated APK until success. Last published release remains development APK #77. Remaining high-priority blockers: authored directional sprite poses/rig and shimmer, physical Android controls/performance, expanded missions and audio.

- 2026-11-22 (CI #118 follow-up): Job 137314775666 failed at `scripts/main.gd:896` during `Native HD2D smoke test` (timeout after assertion), before APK export. Root cause: the smoke test assumed every enemy's initial attack cooldown had expired after 24 × 0.016s; `enemy.gd` initializes cooldown at `0.6 + kind*0.22`, so this is false for all six archetypes. Commit `fb31456` now checks the 0.18s hit-stun after 12 ticks, asserts cooldown remains active, and explicitly expires cooldown before testing the next attack. **Pending:** run Godot smoke, Android export and emulator in CI for this commit; no APK or on-device visual claim until those pass. Priority remains authored 2D directional poses/rig, eliminating shimmer, physical Android validation, content/audio and release readiness.

- 2026-11-22 (combat regression): Added a headless scenario for all six enemy archetypes verifying that a target stepping behind a committed attack heading takes zero damage, even while in reach (commit `635083c`). This guards the existing dodge/telegraph mechanic, not new animation art. GitHub Actions and Android export for this commit are **pending independent verification**. Existing run #118 failed at the native smoke stage; the prior cooldown-related test fix is present in branch source, but its CI outcome is not yet established. Blockers: passing smoke and Android export, authored directional animation poses, device capture, content/audio and release QA.
