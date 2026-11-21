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

## Progress log
- 2026-11-21: Created quality-gated roadmap. This documentation change is **not** a gameplay fix, APK build, or visual validation.
