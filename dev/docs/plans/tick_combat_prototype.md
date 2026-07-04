# Tick Combat Grey-Box Prototype

## Goal

Validate, in an isolated grey-box scene, that player-clocked tick combat — every executed player input advances the world by exactly one tick — plays as a fluid action game while keeping this project's telegraph/flank/guard combat identity. The prototype is the go/no-go gate for the full conversion described in the tick combat rework plan: it must answer "is flanking a telegraphed charger fun" before any production system is touched.

## Requirements

1. The player is a grid actor with four verbs — step (4-directional), normal attack, mobility skill, wait — under one universal time contract: any executed verb advances the world exactly one tick, aiming with the mouse costs nothing, and an illegal input is soft-denied without consuming a tick. A single currency exists so a telegraph counted in "your actions" can never lie.
2. Each tick resolves in a fixed three-stage order — player action first, then enemy attacks whose countdown reached zero detonate on their locked tiles against the player's post-action position, then enemy movement, facing, and new telegraphs — so stepping out of a displayed danger tile is always safe and standing in one is always punished.
3. Tiles are exclusive: one actor per tile, enemies block ordinary player steps (grid occupancy replaces real-time collision jank cleanly and makes being surrounded a real threat), and the dash is the pressure valve that passes through occupied tiles.
4. Two grey-box enemy kinds exercise the read-flank-punish loop: a slow melee that turns at most 90 degrees per tick and strikes one adjacent telegraphed tile, and a charger that telegraphs its full travel line and destination two ticks ahead. The charger is the kill-criteria enemy — baiting and flanking it exercises every prototype mechanic at once.
5. Input feel meets action-game fluency: held movement repeats at roughly 7 inputs per second, one action buffers during animation, and no animation longer than about 100 ms ever blocks input.
6. The mobility slot ships Dash (instant: straight line up to 5 tiles, cursor picks the landing cell clamped to the line, obstacles, and occupancy; every enemy passed is hit) and can be debug-toggled to Smash (windup: choose a cell within 3 tiles, one windup tick with the 3x3 area telegraphed, the next input releases, any other verb cancels without refunding the spent tick). The toggle exists to validate the slot grammar and the windup grammar, not to ship a real reward.
7. Every commit executes exactly what its preview showed at press time — attack direction, dash path and landing, smash area — and player-side previews use a visual language clearly distinct from enemy danger tiles.

## Design

### Time and speed

All verbs cost one tick; there are no hidden cost multipliers. Slowness, where it exists, is expressed as explicit windup ticks (Smash carries one). Actor speed fields exist in the prototype's data as an energy skeleton, but every actor is locked to the baseline value so the gate isolates core feel from speed variables; speed variation is later work.

### Direction and damage

The player has no facing; attacks aim in the 4-directional quadrant of the mouse. Enemy facing defines front/side/back as grid sectors, and a hit's angle is classified from the attacker's origin tile (for dash, the tile the player occupied when entering the target's tile) relative to the target's facing. The current baseline combat numbers carry over unchanged so the prototype's payoff matches the real game's identity:

| Angle | Guard damage                  | HP bypass while guarded |
| ----- | ----------------------------- | ----------------------- |
| Front | 8                             | 0                       |
| Side  | max(quarter of max guard, 16) | 0.1                     |
| Back  | max(half of max guard, 32)    | 0.25                    |

Staggered targets take 1.0x hit damage from normal attacks and 2.0x from dash hits, as today.

### Enemies

The melee enemy repositions toward the player, faces, telegraphs one adjacent tile for one tick, strikes, recovers. Its 90-degrees-per-tick turn cap is the flank knob: circling it costs two to three steps and pays off with the side/back multipliers. The charger telegraphs a straight line plus a destination marker, waits two ticks (two player actions), then traverses; it exists to prove that "read the intent, sidestep, punish the recovery from behind" reads clearly and feels earned.

### Kill criteria

The prototype passes when baiting the charger, sidestepping, flanking, and landing a back hit feels like an earned action payoff rather than menu-driven tactics, and the input flow supports both continuous held-key movement and stop-anytime deliberation with zero friction between the two modes.

## Non-Goals

1. No production integration: the existing arena, wave controller, reward system, saves, and scene routing stay untouched; the prototype scene is reachable through debug means only.
2. No art or audio pass — grey shapes, and existing placeholder sounds at most; nothing visual is acceptance-relevant beyond legibility.
3. No speed variation: no free-step meter, windup reduction, or cooldown stats — the speed fields exist in data but stay locked at baseline.
4. No run loop: no waves, rewards, death flow, or terrain mutation; enemies respawn by debug key on a static land layout.
5. No real Major/Minor effects and no reward-store wiring; the Smash toggle is a debug switch only.

## Acceptance Criteria

1. A tester can bait the charger's two-tick telegraphed charge, sidestep, flank, and land a back hit, and reports the loop as fun and earned rather than mechanical.
2. Holding a movement key traverses the arena fluidly with no perceived latency or animation blocking; releasing stops the world instantly, and a stopped player can aim and think indefinitely at zero cost.
3. Over a full session, no enemy attack ever hits a player standing outside a displayed danger tile at detonation, and none misses a player standing inside one — zero telegraph deviation.
4. Every commit matches its preview exactly at press time, including dash landings clamped by obstacles and occupied tiles.
5. Windup start, release, and cancel are understood without instruction, and a cancel never refunds the spent tick.
6. The session ends with an explicit go/no-go verdict recorded in the tick combat rework plan before any production conversion begins.
