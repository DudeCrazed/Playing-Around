# PARABOUND — pixel PvP

Open **PARABOUND.rbxl** in Roblox Studio and press **Play**. The current scope is player duels, an explicit practice bot, free training, and a short tutorial. Story, Breach, shops, quests and RPG menus have been removed from the player flow.

Original pixel characters use small palette sprites with articulated, smoothly blended movement and attack poses. They are inspired by the proportions/readability of Terraria rather than copied characters or artwork. The physical Roblox avatar is hidden behind a uniform collision body.

## Play

The game opens in the tutorial courtyard. **M** or **Select** opens Play / Loadout / Settings. Choose **Find Duel** to wait for another real player in the same server. That queue never secretly fills with bots. **Practice Bot** is explicitly labeled and works alone. The three courts are Terrace Bellcourt, Scarwood Crossing and Emberforge Bridge.

Duels use three stocks and rising Impact. Fall off the stage to lose a stock. Weapons lock during a duel. Both real players must agree to a rematch. Ratings and wins are kept for the current server session only; cross-server matchmaking/persistent ranking is not configured.

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | A / D, arrows | Left stick |
| Jump / double jump | Space | A |
| Light / heavy | J / K, mouse buttons | X / Y |
| Parry, then hold guard | F | LT |
| Dash | Q | B |
| Resonance Cut | E | RT |
| Feint before commitment | G | LB |
| Fast fall / platform drop | S / Down | D-pad down |
| Menu | M | Select |

Touch controls use separate movement/jump and combat pads. Prompts update for keyboard, touch and controller.

The short tutorial teaches moving, double jumping, dashing, connecting attacks, parrying and perfect parrying. You can leave for PvP or practice at any time. Raised platforms permit upward passage, landing from above and dropping through. A small silver glint marks attack commitment. Tapping Parry retains its window after release; holding transitions into Guard. Missed parries have recovery.

## Verified in this rebuild

- **97 combat assertions passed in actual Studio**, covering timing, active windows, tap/hold guard, perfect/normal parries, buffering, interruption, hurtboxes, jump limits, one-way shelves, impulse serials and hit-stop restoration.
- **Two-client local server test passed 11 integration assertions**: separate tutorial rooms; real-player queue pairing without a bot; opponent Impact from a hit; a valid opponent parry; three stock losses; winner/rating; mutual rematch. Server-scripted test actions were used; this is not a long manual balance playtest.
- Real keyboard input produced a double jump (root peak Y≈15.7, count2) and a 44-stud/s dash. Idle drift was corrected to zero.
- Actual owner physics: only HRP collides; jumped through a shelf, landed at rootY≈10.198, and dropped to rootY≈3.199.
- Three real attack inputs advanced the tutorial attack step. An asynchronously timed virtual keyboard tap produced a perfect parry and completed onboarding.
- iPhone 13 landscape simulation: touch enabled, compact layout visually checked, movement and jump buttons activated using simulated pointer input. Xbox simulation: gamepad enabled and mapped ButtonA double jump verified. Physical hardware remains untested.
- Current source and QA scripts compile. Final solo console checks have no game-script errors; an existing Studio plugin logs a deprecated GetCollisionGroups warning.
- Render samples varied with Studio context: fixed 15 FPS in some test views; a focused sample measured about 55 FPS and average sprite-update time 0.17ms for two fighters. This is not a release/mobile performance certification.

See tests/QA_RESULTS.json for the saved evidence. The world contains four small scenes with about 650 anchored parts; competitive scene streaming is disabled to avoid missing collision while switching courts.

## Source and tests

- src/server/Bootstrap.server.luau — lifecycle, tutorial, real duel queue, bot decisions, stock/results/rematch.
- src/server/Combat.luau — validated intent and authoritative combat/impulse packets.
- src/server/World.luau — original layered diorama geometry and collision decks/shelves.
- src/shared/PixelRenderer.luau — original pixel art and continuous articulated animation.
- src/shared/Content.luau — weapon/content definitions.
- src/client/Client.client.luau — PreSimulation movement, input, camera, responsive UI and effects.
- Install.luau — complete installer for the current six active modules/world.
- tests/CombatQA.luau — isolated Studio combat fixtures.
- tests/MultiplayerQA.server.luau — temporary automated driver for StudioTestService; not part of the player experience.

The old broad-game milestone is preserved in Git history. The legacy Progression module is not installed or run by the PvP build. No dangerous development commands are exposed to ordinary clients.

## Remaining practical limits

The place is unpublished. Real-player duels currently pair players in one server; publishing, persistent ratings, cross-server matchmaking, sustained network/latency testing and long balance sessions remain outside this verified local build. No money/Robux was spent and nothing was publicly published.

Backgrounds use original stepped Studio geometry, and sprites use original palette rectangles on SurfaceGuis. They do not require external image uploads. Runtime audio references remain the previously verified Creator Store APM/ProSoundEffects assets; no external models/scripts were inserted or audio files redistributed.

Testing follows Roblox's [Studio testing modes](https://create.roblox.com/docs/studio/testing-modes). The uniform body disables competing Humanoid forces using [EvaluateStateMachine](https://create.roblox.com/docs/reference/engine/classes/Humanoid#EvaluateStateMachine).
