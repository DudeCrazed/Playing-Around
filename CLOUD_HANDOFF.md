# PARABOUND — Phase 1 Cloud Handoff (rev 2)

**Status:** source received and traced. **8 confirmed defects fixed**, compiled, and covered by offline checks that fail on the original code and pass on the patched code. **Studio and playtests were not run** (no Studio in this cloud container).

Revision 1 of this file (commit `9e59fcf`) was written before the source arrived. Its suspected causes have now been checked against the code: §5 lists the ones that were ruled out.

---

## 1. Source snapshot

| Item | Value |
|---|---|
| Bundle | `CLOUD_SOURCE_BUNDLE.zip`, sha256 `49feb0f708a5c0b8327bfbb2334b9f7290fa00d3d76428edf9920f5a02029c5d` |
| Baseline (unmodified import) | commit `8b2d3e5` → `parabound/` on branch `claude/laughing-newton-7a8z9n` |
| Fixes | commit `d948848` |
| Portable patch | `parabound/patches/phase1-fixes.patch`. Apply from the local `PARABOUND/` root with `git apply` or `patch -p1`. |

Baseline file sha256 (first 16 hex):

| File | sha256 | File | sha256 |
|---|---|---|---|
| `src/client/Client.client.luau` | `b5f647b06c017d38` | `src/shared/Content.luau` | `91f5118c5962afde` |
| `src/server/Bootstrap.server.luau` | `64e1d0da22ad661f` | `src/shared/PixelRenderer.luau` | `10b06e6435db0c0b` |
| `src/server/Combat.luau` | `110e37cdc5434b51` | `tests/CombatQA.luau` | `a1609dc99564c934` |
| `src/server/World.luau` | `c73f0f062645ed57` | `tests/MultiplayerQA.server.luau` | `58120bc91de91a5a` |

`Install.luau`, `PARABOUND.rbxl` and `QA_RESULTS.json` evidence stay local. **Install.luau must be regenerated** from the patched modules.

## 2. Core action trace (as found)

`Client.combat()` → `send(action, {direction}, GetServerTimeNow(), seq)` → `Bootstrap.handle` (rate limit; injects `payload.timestamp`) → `Combat:Intent` (whitelist, `_canAct`, cooldown, Resonance) → `Combat:Step` (startup, Tell, active-window `_hit`, buffer, ground, hit-stop) → `_impulse` (serial packet; bots get a server velocity write) → `Net.Effect:FireAllClients` → client `Impulse` handler (serial/ArenaId/epoch filtered, matched against predictions) and `_attr` attributes → `PixelRenderer` poses from `AttackState`/`AttackHitAt`/`DashUntil`/… on render.

Movement runs on the owning client in `PreSimulation`. The server checks it every 0.1 s in `Bootstrap` Heartbeat (anti-teleport) and enforces the lane.

## 3. Confirmed defects fixed (ranked by playability)

Line numbers refer to the **baseline** files.

| # | Symptom | Evidence | Fix |
|---|---|---|---|
| **F1** | Rubber-banding after strong hits and air dashes. Ring-outs fail at high Impact. | `Bootstrap.server.luau:259-270`: the speed budget is 28 st/s once `LaunchUntil` (0.35 s) or `DashUntil` (0.16 s) ends. But the client keeps launch speed for 0.35 s and then slows at only 70 st/s² (`Client:638-658`). At 100% Impact a Longblade light launches at 56 st/s, so it still travels about 5 studs per 0.1 s after the launch ends, against a 4-stud budget. The server then **snaps the player back and zeroes X velocity**. | `Combat:SpeedAllowance(s, at)`: every impulse raises a per-fighter allowance to \|vX\|+25. It holds through the launch window, then decays at the client's 70 st/s². The validator budgets with `max(old rule, allowance)`. |
| **F2** | "Attacks and abilities don't work". The bot goes passive after about 20 s. | Light costs 7, Heavy 14, Dash 8 and Arcana 24, but Resonance regenerates only 4/s (`Combat:250-255,266`). Mashing lights spends about 16/s. The bot spends about 9.6/s and is dry around 17 s (`Bootstrap:293-296`). Rejections are silent, there is **no Resonance HUD**, and the ability label said READY whenever the cooldown was done (`Client:773-775`). | `Content.ResonanceCosts` = Light **0**, Heavy **10**, Dash 8, Arcana1 24; `ResonanceRegen` **6**/s. Server and HUD share these values. Added a Resonance bar to both fighter cards, and a "NEEDS RESONANCE" / "SURGE LOW" state. |
| **F3** | Hitboxes swing behind the attacker. Parries and guards fail while backing off. | `Combat:_facing` accepts every `Move` (sent at 10 Hz) and every payload `direction`, even mid-attack (`:200-207`). `_hit` uses the current facing (`:129`), and the parry/guard "front" check uses the defender's facing (`:131`). So reversing during startup whiffs, and retreating while parrying gets you hit. **Reproduced offline.** | `Combat:FacingLocked(s)`: facing is fixed through an attack's active frames, the parry window and held guard. Parry/Guard ignore the retreat direction and face the nearest hostile within 16 studs (`_faceThreat`). |
| **F4** | The practice bot "turtles" and stops parrying. | The bot sends `Parry` and never `GuardEnd` (`Bootstrap:299`). `WantsGuard` stays true, so it holds guard and every later parry returns false (`Combat:209`) until its next attack clears it. | The bot sends `GuardEnd` 0.2 s after an accepted parry, and respects `FacingLocked`. |
| **F5** | Attackers float or re-boost after air hits, and parry winners lurch (grows with latency). | For a non-launch hit-stop, `_freeze` stores the server's *replicated* copy of the owner's velocity (`:107`). That copy is stale by at least RTT/2, and Restore writes it back (`:288-289`). | The Restore packet now carries `Resume=true` for non-launch freezes. The owner caches its own velocity when Freeze arrives and restores that. Launch restores stay server-authoritative (invariant kept). |
| **F6** | Double-height jumps and double dashes at high ping. | The client treats a matched prediction as already applied only if it is under 0.22 s old (`Client:487`). Above about 220 ms RTT, the server packet re-applies `Y=44` / `X=44`. Unpredicted packets also overwrite the other axis with the server's stale value (`:497`). | A matched prediction (pending entries already expire at 1 s) is never re-applied. An unpredicted Jump/Drop/FastFall keeps the local X; a Dash keeps the local Y. |
| **F7** | A jump pressed just before landing is lost. | `Intent("Jump")` returns false without buffering while the server hasn't yet seen the landing (`Combat:225-228`). | Still returns false (the existing "Third jump rejected" contract holds) but sets `JumpBufferedUntil`. The existing Step buffer fires it only once the server confirms grounding. |
| **F8** | Resonance Cut, blocks and KOs show no feedback. | The server emits `Arcana`, `Block` and `KO` (`Combat:144,258`, `Bootstrap:157`), but the client has no handler for them (`Client:511-528`). | Small ArenaId-scoped shard bursts: school color on cast, grey on block, a ring plus capped shake on KO. ReducedFlashes and CameraShake settings are respected. |

### Interfaces (all additive; no removals or renames)
- `Combat:FacingLocked(state) → bool` and `Combat:SpeedAllowance(state, serverTime) → number` are new public methods.
- `Combat:_impulse(s, velocity, action, resume?)`: the Impulse packet gains an optional `Resume` field. Older clients ignore it.
- `Content.ResonanceCosts` and `Content.ResonanceRegen` are new.
- **Behavior changes to confirm in playtest:**
  - light attacks are free;
  - regen is 6/s;
  - facing is locked through the active frames, the parry window and held guard;
  - parry and guard auto-face the nearest threat. A guard can still be crossed up, because facing stays locked while held.

## 4. Invariants
All 11 are preserved. The offline suite re-checks five of them:
- tap-parry window kept after release;
- serial-checked impulses that strictly increase;
- launch restore stays authoritative during freeze;
- arena isolation;
- third jump rejected.

F5 refines "freeze/restore preserves knockback" for **self** freezes only.

## 5. Revision-1 hypotheses ruled out by the source
- Parry timestamp mismatch: ruled out. `Bootstrap:234-235` injects a server-synced `payload.timestamp`, and the 80 ms compensation cap works.
- Hard-coded respawn X/Z: ruled out. Every arena sits at X=0 with FloorY=0, and tutorial rooms share Z=0 (`World:92,117,125-144`).
- Ground ray too short: ruled out. The collider is 6.4 tall and the ray is 3.5, so it reaches 0.3 studs below the feet (`Bootstrap:49`, `Combat:181`).
- Per-swing dedupe and arena filter: correct (`Combat:127,130`).
- Client sequence reset: no. The client script persists and resets only prediction state on spawn.

## 6. Checks actually run

| Check | Result |
|---|---|
| `luau-compile` (official Luau CLI), all 6 modules + 4 test files, before and after | **All OK** |
| Offline harness `parabound/tests/offline/run.sh` (real `Content.luau` + `Combat.luau` on mocked Roblox APIs) | **29/29 pass** on the patched source |
| Same spec on the **baseline** source | **11 fail**, as expected: light gating, Heavy cost, regen, facing lock, *reverse input whiffs*, parry facing, *retreating parry gets hit*, guard facing, jump buffer, buffered jump, Resume flag. Invariant-parity checks pass on both. The baseline run stops at the allowance checks because `SpeedAllowance` does not exist there. |
| `git apply --check` of the patch on a pristine extract, then the offline suite | Applies cleanly, 29/29 |
| `tests/CombatQA.luau` (97 existing + 5 new), `MultiplayerQA`, any playtest | **NOT RUN.** Studio-only. I reviewed the existing assertions by hand against the changes and expect them to still pass, but that is unverified. |

The offline harness has no physics. Positions move only when a test moves them, so it validates rules, not feel.

## 7. Remaining issues (not fixed; need Studio or latency reproduction)

| # | Issue | Evidence | Proposed direction |
|---|---|---|---|
| R1 | **Parry is nearly reaction-proof online.** The Tell fires only 80 ms before HitAt (`Combat:165`), the window opens when the server *receives* the press, and nothing rewinds. Reaction time ≈ startup − RTT, which is about 60 ms for a Longblade light at 100 ms RTT. | Design | Hold a hit's confirmation for `min(defender ping, 80 ms)` and accept a parry stamped before HitAt (a "parry grace" window). This touches hit-stop and launch timing, so playtest it first. |
| R2 | Hit tests use server-side positions of client-owned roots (`Combat:128`), which lag. | Design | Short position history plus bounded rewind. Measure the miss rate first. |
| R3 | Client grounded state comes from the server's `Airborne` attribute (`Client:646-653`). Landing acceleration and the jump-count reset lag by about RTT + 0.1 s ("clunky landings"). | Code | A local probe that mirrors `Combat:_ground`. **Not done**, because it can desync the JumpCount-matched predictions (F6). Pair it with sequence-based prediction acks. |
| R4 | `PixelRenderer` reads `LocalActionState/Start/Until` (`:213-220`), but nothing writes them, so attack windups appear only after the round trip. | Code | Wire them in `Client.combat()` with a cancel on rejection; otherwise rejected presses play swings that never hit. |
| R5 | Narrow edge: a client prediction rejected and buffered (F7) at RTT > 0.22 s can still double-boost. | Reasoned | Covered by the same ack redesign as R3. |
| R6 | Character replaced without `Died` leaves its old state in `engine.States` (`Bootstrap:186-190`). `alive()` filters it out, so the cost is a slow leak. | Code | Call `engine:Remove(old)` in `CharacterAdded`. |
| R7 | `_ground` walks `GetDescendants()` per fighter every Heartbeat (`Combat:174`). | Code | Track drop NoCollisionConstraints in a table. |
| R8 | Client jump/dash prediction is blocked for 0.38 s after any parry (`Client:293` `CD_Parry`), even after a *successful* parry, which delays punishes. | Code | Gate on `ParryRecoverUntil`, or skip the gate after success. |
| R9 | The bot walks while attacking, and its parry only reads attacks with startup over 0.13 s. | Code | Difficulty tuning pass. |

## 8. Local validation steps (Studio; unexecuted here)
1. In local `PARABOUND/`, run `git apply patches/phase1-fixes.patch` (copy the patch from this branch first), then regenerate `Install.luau` / sync the 6 modules into the place.
2. Run `tests/CombatQA.luau`. Expect the previous 97 plus 5 new checks to pass. Run `tests/MultiplayerQA.server.luau` and expect 11/11.
3. Set Studio Settings → Network → **Incoming Replication Lag = 0.1** (if your build has it). Then Test → **2 players**.
4. **F1:** in a duel, raise the rival to ~120% Impact, then land a Greatblade/Longblade heavy. Pass: they fly off without snapping back, and `DevelopmentHarness Inspect → Movement.Corrections` stays 0. Repeat with an air dash.
5. **F3:** hold the direction away from the rival during a Light's startup, and confirm the hit still lands forward. As defender, hold away and tap F just before contact; it should parry.
6. **F4/F2:** fight the Practice Bot for 2 minutes. It should keep attacking and never sit in guard. Your lights should never fail, and the Resonance bar and "NEEDS RESONANCE" label should track.
7. **F5/F6:** at 0.25 s lag, jump, double jump and dash repeatedly. There should be no extra-high jumps or second dashes, and air hits shouldn't make you float.
8. Re-check the invariants: one-way shelves both directions plus drop, tap-parry retention, the 3-stock flow, rematch, and the tutorial end to end.

## 9. Visual/content pass specification (ordered by player impact)

**Facts from the source that shape this:**
- Fighters are anchored limb Parts carrying `SurfaceGui` palette rectangles (`PixelRenderer.sprite`: `CanvasSize` = pixel grid, `LightInfluence = 0`). They are crisp at any zoom and need no image uploads.
- Effects are Neon `Part` shards (`Client.shard`). Backgrounds are stepped Studio geometry (`World`).
- Audio uses five Creator Store IDs in `Content.Audio`.
- Roblox has no custom shader API.

1. **P0 readability.**
   - Lengthen or brighten the commitment Tell and give the parry window its own sound, because of R1.
   - Give the parry flash a 1–2 frame white silhouette (swap the palette in `PixelRenderer`).
   - Keep the training hitbox overlay toggle on the backlog.
   - Characters keep a dark 1-pixel outline row in their palettes. Backgrounds stay lower in value and saturation than fighters.
2. **P1 animation.**
   - `poseFor` already blends with exponential smoothing (`alpha` 19/34).
   - Add anticipation and overshoot keys driven by `AttackHitAt`, not separate timers.
   - Hit reactions should snap in with no blend.
   - Add a short landing squash using `JumpCount` and `Airborne` transitions.
3. **P1 pixel crispness.**
   - SurfaceGui rectangles are already resolution-independent. Keep `P` (pixel size) an integer multiple on screen.
   - Prefer limb angles in 15° steps if rotated edges look noisy.
   - Never use `BlurEffect` or `DepthOfFieldEffect` on gameplay.
4. **P2 parallax.**
   - Backgrounds are static geometry. Add 3–4 layers that are offset each `RenderStepped` by `cameraX * factor` (0.1 / 0.3 / 0.6). They are cosmetic only and must never carry `DropThrough` or collision.
   - Try `LightInfluence` around 0.3 on fighter SurfaceGuis to pick up stage tint, and verify contrast.
5. **P2 sound and VFX.**
   - Add `SoundGroup`s (SFX/Music/UI) behind the existing settings toggles.
   - Use ±5% `PlaybackSpeed` variation on hits.
   - Use `ParticleEmitter` flipbooks only if shards prove too costly.
6. **P2 characters and customization.**
   - Add palettes and sprite rows per cosmetic. The collider stays uniform (invariant), so cosmetics never change hitboxes.
7. **P3 weapons and magic** (only after R1–R3 are settled).
   - Extend `Content.Weapons` and `Combat.TIMINGS`.
   - Every new move must have a Tell, be parryable or reflectable, and cost Resonance from `Content.ResonanceCosts`.
8. **P3 cosmetic shop.**
   - Server-validated soft currency. `DataStore` `UpdateAsync` with session locks.
   - Optional Developer Products with **placeholder IDs** and an idempotent `ProcessReceipt`.
   - Cosmetic only, and no paid random items.
9. **P3 KO effects.** These hook into the new `KO` client handler.
   - Default: **Pixel Shatter** (palette-colored shards, no blood).
   - Optional: non-red **Pixel Splash**.
   - Optional: gore-free **Puppet Pop** (clean rig pieces that fade in about 0.5 s).
   - Per Roblox maturity guidance, pixelated or off-color blood is "unrealistic" (Minimal/Mild), while severed body parts are Restricted examples. Answer the maturity questionnaire honestly, keep everything selectable per player, and default to Shatter.

## 10. Budget
No authoritative billing telemetry is available in this environment, so I report no spend figure. Work was kept bounded: a single read of each module, scripted edits, one toolchain download, and no sub-agents.

## 11. Next concrete integration action
On the Mac, in `/Users/bobby4abby/Documents/Codex/2026-10-02/create-a-100x100-brick-in-studio/outputs/PARABOUND`:
1. Copy `parabound/patches/phase1-fixes.patch` from branch `claude/laughing-newton-7a8z9n` and run `git apply patches/phase1-fixes.patch`.
2. Regenerate `Install.luau`.
3. Run §8 steps 2–7 in Studio and record pass/fail in `tests/QA_RESULTS.json`.
4. If F1–F8 hold, take R1 (parry grace window) as the first Phase 2 design change.
