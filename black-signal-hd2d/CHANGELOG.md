# Changelog

## v0.9.0
- Replaced placeholder rectangles with textured building sprites across the street.
- Six types — residential neon block, industrial warehouse, market, corporate tower, slum apartments, medical clinic — each with separate front/left/back/right art.
- Deterministic static details: lit windows, panel aging, neon signs, roof structures and glow, no temporally unstable procedural noise.
- Texture atlas generated as part of the Android build and checked by the Godot smoke suite; uploaded separately as a CI artifact.
- Current engine remains 2D with planar billboard facades: these are *not* 3D meshes or PBR material maps.
- Visual inspiration: six building render sheets supplied in the conversation. Exact model-generated raster sheets were not copied into the repository.


## v0.8.1
- Sidewalk and road crates now have real world-space solid collision and projectile line-of-sight blocking (not screen-space decoration).
- Rin and ground enemies slide around crate edges; basic enemy flank steering responds when its direct approach is blocked.
- Enemy ground attacks cannot damage Rin through cover; shooting through cover no longer hits ground enemies. Drones intentionally shoot above low cover.
- New static cover tests for collision, sliding, hitscan, and protection against enemy fire.
- Limitations: rudimentary AI, low-fidelity art, no realistic ballistics or destructible cover.


## v0.8.0
- New Chapter 01 mission state machine: recover terminal data → clear six enemies → escape.
- Added objective HUD, spatial waypoint and minimap marker, proximity-based on-screen interaction and E key support.
- Added completion/replay results and persistent best time and completion count.
- Added regression checks rejecting out-of-range, wrong-order and insufficient-kill interactions.
- Remaining: performance, animation quality and UX need physical Android validation; this is not a finished AAA product.
