# PARABOUND — Phase 1 Cloud Handoff

**Status: BLOCKED. No source was supplied, so no code was changed.**
Date: 2026-10-04 · Environment: remote Claude Code cloud container (Linux), no Roblox Studio, no Studio MCP, no access to `/Users/bobby4abby/...`.

---

## 1. Source snapshot

| Item | Result |
|---|---|
| Repository | `DudeCrazed/Playing-Around`, branch `claude/laughing-newton-7a8z9n` |
| Base commit | `50c99387482be6a5b43d1f2c28ef28c3026e1511` ("Initial commit"), which contains only `README.md` (60 bytes) |
| `CLOUD_SOURCE_BUNDLE.md` | **Not present.** I searched the repo and the whole container filesystem by name. |
| PARABOUND ZIP / `.luau` / `.rbxl(x)` | **None found** anywhere in the container |
| Other account repos | `DiaNutri`, `topops-field-ops`, `TheChaosHub-AFK-Bot`, `Playing-Around`. None of them is PARABOUND. |
| Source hashes | N/A. There is nothing to hash. |

The six Luau modules, the docs and the tests never reached this environment.

## 2. Implemented fixes and affected interfaces

**None.** I did not write patches for code I could not read. A guessed diff against unknown symbols would not apply, and it could break working code. No interfaces changed.

## 3. Checks actually run

| Check | Result |
|---|---|
| `git status` / `git log` / `git ls-remote` | Clean tree. One commit. Remote has only `master` (same commit). |
| Filesystem search for the bundle, `*parabound*`, `*.luau`, `*.rbxl*`, and recent `*.zip` files | 0 matches |
| `list_repos` (account repos) | 4 repos, no PARABOUND |
| Luau unit tests / selene / StyLua / Studio playtest | **Not run.** No source and no Luau toolchain/Studio here. |
| Web lookup: Roblox content-maturity wording for blood/violence | Done. Used in §7.9. |

**Runtime claims: none.** I made no playtests and reproduced no bugs.

---

## 4. Phase 1 audit plan (use this for the rerun)

These are **hypotheses to check, not confirmed bugs.** Each row is a common defect in this architecture (hidden collider, HRP-only collision, PreSimulation physics, serial-checked impulses), mapped to a symptom the user reported. On the rerun, confirm or rule out each one with file/symbol evidence, in this order.

### 4.1 Trace order for each action

For each of Light/Heavy attack, Special/ability, Parry, Jump, Dash and Drop-through:
`client input` → `RemoteEvent intent (name, payload, client time)` → `server validate (whitelist, state, cooldown, resource, rate limit)` → `resolve (hitbox query or impulse)` → `replicate (attribute/remote/packet + serial)` → `client apply (prediction reconciliation)` → `animation / VFX / HUD`.
Record the exact function at each hop. A hop with no function is a defect.

### 4.2 Ranked suspect list

| # | Symptom | Likely root causes to check | How to confirm locally |
|---|---|---|---|
| 1 | "Abilities don't work" | (a) The client action key doesn't match the server whitelist/table key (case, renamed enum). (b) Server state stuck non-idle (attack/hitstun timer cleared by freeze/restore, respawn or checkpoint, but state never reset). (c) Cooldown compares client `os.clock()` with server time. (d) The rate limiter silently drops buffered inputs. (e) Server rejects with no log. | Temporarily log every server rejection with its reason, then press each action once from idle. Any silent drop is the bug. |
| 2 | "Faulty hitboxes" | (a) The server queries the target's *server-side* position, which lags the owning client by about RTT/2 plus interpolation, so hits that look clean miss. (b) The hitbox offset uses the collider's `LookVector` instead of the facing flag. A side-view collider often doesn't rotate, so the box always spawns on one side. (c) Per-swing hit dedupe is missing (multi-hit) or keyed wrong (blocks the next swing). (d) `OverlapParams` misses the ArenaId filter, or uses a collision group that excludes HRPs. (e) The active-frame window is measured from server receive time, not attack start. | Add a dev toggle that draws server hitbox parts for 0.2 s per active frame. Test facing left and right, and test with Studio network lag. |
| 3 | Parry timing feels wrong | Mixed clocks (`tick`/`os.clock`/`GetServerTimeNow`). The window opens on server receipt, not press time. Releasing Parry cancels the window (this violates the invariant). Parry checked after damage is applied in the same step. | Script both players. Press Parry at fixed offsets (−100…+100 ms) around the attack's active start and log the server verdict. |
| 4 | Clunky jump/dash | (a) The movement controller writes horizontal velocity from input every PreSimulation, which erases knockback and dash. (b) No coyote time (~80–100 ms) or jump buffer (~100 ms). (c) The ground ray starts inside the collider or is too short, so it flickers grounded/airborne. (d) The impulse serial compares `>=` instead of `>`, or predicted serials are never acked, which double-boosts or drops boosts. | Log `grounded`, velocity and serial each frame for 2 s around each action. |
| 5 | One-way shelf glitches | Collision toggled on the server while the client owns physics (the toggle must run on the network owner). The drop-through window expires before the collider clears the shelf. A shelf counts as ground from below. | Jump up through every shelf, drop through and land on each one. Repeat at low FPS (Studio frame-rate cap) to expose timing bugs. |
| 6 | Bot misbehavior | Bots call internal functions and skip the validation path, so their behavior differs from players'. Decision tick runs every Heartbeat with no reaction delay (spam or perfect parries). Bots keep acting after game over. No shelf awareness. | Route bot actions through the same intent validator as players. Log the bot decision rate. |
| 7 | Stock/results/rematch | The blast zone fires more than once per fall (no per-life debounce). Double KO is unhandled. Rematch doesn't reset state, cooldowns, serials, freeze or knockback. `PlayerRemoving` mid-match leaves results hanging. | Play 3 matches back to back, including a rage-quit and a simultaneous KO. |
| 8 | Random glitches over time | Per-character connections are never disconnected on respawn, so handlers stack: doubled inputs, doubled VFX, memory growth. | Count active connections, or log handler entry counts, after 5 respawns. |

### 4.3 Regression checks to add once source is available

Write these against the real module APIs. Keep them pure-logic where possible (no Studio needed):

1. **Cooldown:** an action is accepted, then rejected until `cooldown` has elapsed on the *server clock*, then accepted again.
2. **Impulse serial:** a duplicate or stale serial is ignored, a newer one is applied exactly once, and predicted plus confirmed impulses add up to one boost.
3. **Parry window:** press then immediately release, and the window stays open its full duration (invariant). A press outside the window fails.
4. **Hitbox facing:** for facing ±1, the hitbox center lies on the facing side of the attacker.
5. **Per-swing dedupe:** one swing hits a target once. The next swing can hit it again.
6. **Freeze/restore:** velocity before freeze equals velocity after restore.
7. **Stock:** one fall removes exactly one stock, and a simultaneous KO resolves deterministically.
8. **Rematch reset:** every per-match field returns to its initial value (snapshot comparison).
9. **ArenaId:** a hit query from arena A never returns a target in arena B.
10. **World rebuild:** after two rebuilds, exactly one owned world folder exists.

---

## 5. Remaining bugs and local validation steps

No bug is confirmed yet (no source). Run these in Studio on the local machine after the Phase 1 fixes:

1. **Test → Clients and Servers → 2 players** (plus a 3rd if testing arena isolation).
2. If your Studio version has it, set **Studio Settings → Network → Incoming Replication Lag** to about 0.1 s for hitbox and parry tests.
3. Turn on the dev hitbox overlay (row 2 above) and the server rejection log (row 1).
4. Walk the §4.2 table top to bottom. For each row, record **pass/fail + output log excerpt**.
5. Run 3 full matches vs a practice bot and 1 player-vs-player match. Check results and the rematch flow each time.
6. Run tutorial and free training start to finish. Confirm checkpoints reset movement history.
7. Rebuild the world twice mid-session. Confirm only one owned folder exists and no effects leak across ArenaIds.

---

## 6. Invariants (carry forward unchanged)

Uniform hidden collider with Humanoid state forces disabled · only HRP collides and owner torso-collision rewrites are suppressed · physics writes in PreSimulation, sprites/camera in render · server-owned damage, parry, cooldowns, stocks and results · serial-checked impulses that cannot double-boost · freeze/restore keeps knockback · one-way shelves from below/above plus temporary drop constraints · ArenaId isolation · world rebuild replaces its owned folder · checkpoint resets movement history · tapping Parry retains the window.

---

## 7. Local visual/content pass specification (ordered by player impact)

Engine facts used below are standard, documented Roblox features. **Roblox has no custom shader or fragment-program API.** All "shader-like" looks must come from art, GUI properties, `Lighting` post-effects, particles and beams. I invented no asset IDs, product IDs or uploads. Every ID is a placeholder for you to fill in.

### P0: Combat readability (affects every match)
- **Telegraphs from server frame data.** Drive startup, active and recovery poses from the same data table the server uses for timing. Animation timing must never be a separate copy.
- **Hitstop:** 3–6 frames on hit and about 8 on a successful parry. Freeze sprite poses and VFX locally. Physics freeze stays server-authoritative (invariant).
- **A parry the player can't miss:** a white silhouette flash (1–2 frames), a distinct high-pitched sound, a short ring burst, and a brief `ColorCorrectionEffect` contrast pulse (≤100 ms).
- **Character vs background contrast.** Characters get a 1-px dark outline baked into the art. Backgrounds stay lower in saturation and value. Use a per-player rim/team color only if it doesn't fight cosmetics.
- **Optional hitbox overlay** in training mode (reuse the dev overlay from §4.2).

### P1: Animation posing and blending (the "smooth articulated" goal)
- **Cut-out rig:** separate sprites for head, torso, upper/lower arm, upper/lower leg and weapon, each with a pivot. Store poses as keyframe tables (`{limb = {angle, offset}}`) and interpolate with easing (ease-out for strikes, ease-in-out for idle).
- **Blending:** crossfade between poses over 2–4 frames. Hit-reaction and attack poses cut in instantly with no blend-in, so commitment stays readable.
- **Rotation and pixels.** Smoothly rotating a `Pixelated` image gives jagged rotation. Pick one approach per project and apply it everywhere:
  - pre-render limb rotations at authoring time (RotSprite-style) at 15°/22.5° steps and swap images, or
  - author limbs at ≥4× resolution so smooth rotation stays clean.
- **Secondary motion:** a 1–2 frame lag on hair, cape and weapon trail. Light squash/stretch on jump and land, done through size, not rotation.

### P1: Pixel crispness and edge treatment ("smooth edges without blurring pixels")
- For GUI-based sprites (`ImageLabel` in `SurfaceGui`/`BillboardGui`/`ScreenGui`), set `ResampleMode = Enum.ResamplerMode.Pixelated`.
- For textures on 3D parts (decals, particles, beams) you can't control filtering. Upload art integer-upscaled ×4–×8 with nearest-neighbor before upload, so engine filtering only softens the outer pixel edge. Roblox caps image uploads at 1024 px, so pack accordingly.
- **Edge smoothing:** do it at authoring time with hand-placed 1-px anti-alias pixels on silhouette curves *only*. Keep integer pixel scale on screen and snap the camera to the texel grid when idle. **Do not** use `BlurEffect` or `DepthOfFieldEffect` on gameplay layers.

### P2: Parallax 2D scenes
- 3–5 layers: far sky (static or very slow), distant silhouettes, mid set dressing, playfield, and a sparse foreground. Foreground must stay translucent or clear of the fighting area.
- **Implementation:** with a low-FOV, near-orthographic camera, depth alone produces little parallax. Instead, offset each layer each `RenderStepped` by `cameraDelta * factor` (for example 0.1 / 0.3 / 0.6 / 1.0 / 1.2). Cosmetic layers only, never colliders.
- **Lighting:** `SurfaceGui`/`BillboardGui` have `LightInfluence` and `Brightness`. Use partial light influence so sprites pick up scene tint. A per-stage `Atmosphere`, `ColorCorrectionEffect` grade and gentle `BloomEffect` on emissive VFX only.
- **Per-stage palette:** at most about 3 hue families. Keep the playfield band highest in value contrast.

### P2: Sound and VFX
- `SoundGroup`s: Master, SFX, Music, UI. Expose sliders.
- Use ±5% random `PlaybackSpeed` on repeated hits so they don't sound mechanical.
- Priority order: parry > hit confirm > KO > movement > ambience. Cap simultaneous instances per sound.
- Pixel VFX: `ParticleEmitter` with `FlipbookLayout` flipbooks drawn at the game's pixel scale. Low counts and short lifetimes. Every effect is ArenaId-scoped and parented under the arena's effect folder.
- Screen shake: capped, scaled by knockback, and with an accessibility toggle (reduce/off).

### P2: Original characters and customization
- Silhouette-first design: each fighter must be identifiable in a black-fill thumbnail. Original designs only. Terraria-*inspired* proportions (big head, chunky limbs) are fine. Copied sprites, palettes or items are not.
- Customization slots map onto the rig: head/hair, body, arms, legs, weapon skin, trail color and KO effect. Cosmetic only, with identical hitboxes (the collider is uniform by invariant).

### P3: More weapons and magic (only after the §4 bugs are fixed)
- Data-driven definitions: `startup/active/recovery` frames, damage, base and growth knockback, hitbox list per active frame, parry interaction (parryable / unparryable-with-tell / reflectable), cooldown and resource cost.
- **Balance rule:** fast weapons trade reach or knockback for speed. Every projectile is parryable or reflectable. No new option beats the parry with no counterplay.
- Magic projectiles are server-authoritative, ArenaId-tagged and lifetime-bounded, and run through the same validation path players and bots use.
- Add at most 1–2 at a time. Test each against every existing weapon in training mode.

### P3: Functional cosmetic shop
- Soft currency earned from matches, granted by the server only on validated results (no client-reported rewards).
- Persistence: `DataStoreService` with `UpdateAsync`, session locking, retry/backoff and a schema version.
- Optional Robux items via **Developer Products / Game Passes** with **placeholder IDs**. `MarketplaceService.ProcessReceipt` must be idempotent (record `PurchaseId`, and return `PurchaseGranted` only after a successful save).
- Cosmetic only, never stat-affecting. **No paid randomized items** (loot boxes).
- UI: preview on the live rig, owned/equipped states, and confirmation before spending.

### P3: Configurable stylized KO effects
Roblox's current maturity guidelines ([create.roblox.com][cm], [help.roblox.com][hc]) say:
- **Unrealistic blood** (pixelated, a different color or a different shape) at *light* levels fits **Minimal**. *Heavy* unrealistic blood moves the experience to **Mild**.
- Realistic blood raises the label to Moderate or Restricted.
- *Severed or severing body parts* and dismemberment are listed as **Restricted** examples (for graphic, realistic depictions).

Recommendation:
- **Default KO effect: "Pixel Shatter."** The character breaks into its own palette's colored pixels and dissolves within about 0.5 s. No blood. This is the safest choice and the clearest for competitive play.
- **Optional "Pixel Splash"** in a non-red, stylized color (for example the character's accent color). Brief and light, not pooling. Keeps you in Minimal/Mild.
- **"Puppet Pop" (detached limbs):** only as clean, cartoon rig pieces that pop off and bounce, with no wounds, stumps or blood, and fade within ~0.5 s. Classification is Roblox's call, so answer the maturity questionnaire honestly. If it pushes the label above your target, drop it.
- All KO effects must be selectable per player in settings, default to Pixel Shatter, never hide the next stock's respawn, and stay ArenaId-scoped.

---

## 8. Budget usage

No authoritative billing telemetry is available in this environment, so I report no figure. Work was kept small: a few shell and file searches, one repo listing, one web search, and this document.

## 9. Next concrete integration action

**Make the source reachable, then rerun Phase 1.** Either:

- **Recommended:** run Phase 1 in **local** Claude Code on the Mac, at `/Users/bobby4abby/Documents/Codex/2026-10-02/create-a-100x100-brick-in-studio/outputs/PARABOUND`, with Studio MCP connected. Only that environment can read the code *and* playtest. Use §4 as the checklist.
- **Or, cloud:** commit the six modules plus docs and tests to this branch (for example under `parabound/src`, `parabound/docs`, `parabound/tests`), or attach `CLOUD_SOURCE_BUNDLE.md` to the session, and start a new cloud session. Runtime tests there will still be marked unexecuted.

[cm]: https://create.roblox.com/docs/production/promotion/content-maturity
[hc]: https://en.help.roblox.com/hc/en-us/articles/8862768451604-Content-Maturity-Labels
