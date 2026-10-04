# PARABOUND — PvP pixel rebuild

User scope replaces the broad original brief: player PvP only, plus a short movement/attack/parry tutorial. Original Terraria-inspired pixel characters with smooth articulated animation. No Story/Breach/economy player flow.

## Routing / ownership
Four GPT-6.1 Sol workers completed World (Medium), Combat (High), Client (High), PixelRenderer (High). Root owns Bootstrap, Content, integration, runtime QA and saved place. No nested workers. All changes preserve the previous milestone in Git.

## Implemented and installed
- Flat original palette sprites, articulated walking/jumping/dashing/guard/attack/hurt poses, mirrored facing, pixel swords/spears, small hit-stop and blade afterimages. No Roblox avatar geometry is shown.
- Compact Play/Loadout/Settings UI, impact/stocks/guard cards, bounded side camera, concise tutorial, four weapon choices.
- Three bright layered pixel-diorama duel stages and one tutorial courtyard; no foreground scenery obstructs fighters.
- Real-player duel queue, explicit practice bot, three-stock ring-outs, rematch/forfeit, session rating/statistics. No bots in the real-player queue.
- Server active-window hit validation, feints before tell, tight hurtboxes, parry/guard/recovery, input buffering, authoritative impulse packets, client jump/dash prediction, hit-stop restoration.
- Uniform invisible collision root, Humanoid state machine disabled, PreSimulation movement, upright/lane constraints, one-way jump shelves and platform drop-through.
- Tutorial six steps: move, double jump, dash, attacks, parry, perfect parry. Skip to PvP/practice is always available.

## Actual QA so far
- Combat suite: final 97 checks passed in Studio (also worker deterministic mocks), including retained tap-parry windows and one-way ground filtering.
- Real keyboard input: double jump reaches root Y15.7, count2; dash VX44.
- Idle drift corrected to zero by disabling competing Humanoid forces.
- Client-only torso collision rewrites fixed: only HRP collides.
- Jump through shelf from below, land at rootY10.198, drop to rootY3.199 — passed in actual client physics.
- Pixel art visually reviewed in native Studio. Camera/body/input fixes integrated and no game errors in current solo console (existing plugin emits deprecated GetCollisionGroups warnings).
- Programmatic two-client StudioTestService test passed all 11 assertions twice: tutorial room isolation, real-human pairing, no bot, hit/parry, three stocks, winner/rating and mutual rematch. Temporary driver removed.

## Current files / state
Source in src/. Install.luau generated from current 6 live modules; legacy Progression excluded from installation. PARABOUND.rbxl now contains the latest PvP rebuild; Studio confirmed the exact local Saved path.
Primary Studio id af14ff8c-8065-4443-8a13-c19824d59c93, now Edit. Device restored to default after iPhone13/Xbox testing.

## Final verification / limits
- Three actual keyboard attack inputs advanced the tutorial; timed virtual keyboard tap produced a perfect parry and completed onboarding.
- iPhone13 landscape Touch=true: compact layout reviewed, movement/jump pads activated by pointer. Xbox GamepadEnabled=true: mapped ButtonA double jump tested; prompts adapt. Physical hardware untested.
- Tap parry release fixed; tutorial knockback reduced to keep learning close. Checkpoint resets clear movement-history correction state.
- Focus-sensitive render samples: 15 FPS in some Studio contexts; focused sample ~55 FPS, average PixelRenderer Step .17ms for two fighters. No full performance certification claimed.
- Rating/preferences/tutorial progress are session-only. Player queue is local-server. Cross-server/public release/adverse-network/long-balance work remains unverified.
- Final current source compiles and solo console has no game-script errors. Preview in PVP_PREVIEW.png, evidence in tests/QA_RESULTS.json.
- Source and native project saved privately. No public publishing or paid actions occurred.

## Next user review
Open PARABOUND.rbxl and Play. User requested focus is now PvP/tutorial; any further refinement should stay in that scope. Current workers complete; no active child tree.
