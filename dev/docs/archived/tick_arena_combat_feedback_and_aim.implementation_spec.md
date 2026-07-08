# Tick Arena Combat Feedback And Aim Extraction

Parent Plan: none (standalone spec)

## Goal

Decouple `TickActionController` from result presentation and remove the duplicated aim/plan wrappers it shares with `TickPreviewController`, so verb resolution no longer builds HUD strings or drives result VFX, and preview/commit resolve aim through one shared path. This is the only actionable slice of the `tick_arena_runtime_ownership_split` survey; relocating pure combat files to `common/` and extracting a `TickEngine` contract were deliberately rejected as premature (single-consumer feature; purity is not reusability).

## Summary

`TickActionController` (512 lines) is the last tick-arena file that bundles unrelated concerns end to end. Two of them are worth separating now, and neither depends on the common/tick_arena boundary question:

**Concern 1 — result presentation is welded into verb logic.** The verb methods call `_apply_player_result_message(result)` (a match statement full of HUD strings like `"GUARD SHREDDER!"`, `"%s hit — GUARD BREAK!"`) and `_play_major_trigger_feedback(result, pos)` (Guard Shredder / Execution VFX+SFX), and the controller owns the HUD message timer (`_message`, `_message_time`, `_update_message`). A combat hit resolving should not be the thing that knows the HUD vocabulary. This extracts a `TickCombatFeedback` node that owns the message timer/state, the outcome→string mapping, and the major-trigger VFX/SFX. The controller keeps `set_message` / `current_message` / `state_changed` as a **thin facade** forwarding to feedback, so the external callers (`TickRunController` reward/reset notices, `tick_arena.gd` debug controls, the HUD read) stay unchanged — the facade is what keeps this change small.

**Concern 2 — aim/plan wrappers are duplicated across two controllers.** `_mouse_cell`, `_aim_direction`, `_compute_dash_plan`, `_clamped_smash_target`, and `_chebyshev` exist in both `TickActionController` and `TickPreviewController`, differing only in where the last-aim direction comes from (`_last_aim` vs `action_controller.get_last_aim()`). This extracts a shared `TickAimContext` that owns the `TickActionPlanner` wrapping plus RunBuild range projection; both controllers resolve through it, guaranteeing by construction that a preview can never disagree with what a commit resolves.

What changes: two new small combat files, a slimmed `TickActionController`, a slimmed `TickPreviewController`, one new scene node in `tick_arena.tscn`, one new focused test, and an update to the existing controller-verb test. What does not change: player-facing behavior, the HUD text vocabulary, external message callers, and the input-driven view flashes and smash windup/impact VFX/SFX (those stay in the verb methods — only outcome-driven feedback moves). The two concerns are independent and can land as two commits.

## Requirements

1. Verb resolution in `TickActionController` produces `TickHitOutcome` values and hands them to a presentation collaborator; it contains no HUD result strings and no result-driven VFX/SFX calls. Why: the felt problem is that a hit resolving is coupled to HUD vocabulary.
2. The HUD result text, message timer, and major-trigger VFX/SFX are owned by one presentation object with direct unit coverage on the outcome→string mapping. Why: that mapping currently has no test.
3. External message callers (`TickRunController`, `tick_arena.gd` debug/HUD) keep calling through `TickActionController` unchanged. Why: contain blast radius; those are legitimate action-feedback surface uses.
4. `TickActionController` and `TickPreviewController` resolve mouse cell, aim direction, dash plan, and smash target through one shared object that reads the current last-aim live. Why: preview and commit must never drift.

## Relational Context

- `TickActionController` owns verb dispatch, action economy, and hit application; it delegates all result presentation to `TickCombatFeedback` (call direction: controller → feedback, write). It retains `set_message` / `current_message` / `state_changed` as forwarders to feedback; do not re-point external callers at feedback directly.
- `TickCombatFeedback` owns the HUD message timer/text, the outcome→string vocabulary, and the Guard Shredder / Execution VFX+SFX. It reads `TickPlayer`'s `guard_shredder_sfx_event` / `execution_sfx_event` and is the tween parent for `MajorTriggerFeedbackVFX`. It emits a message-changed signal on set and on timer expiry; `TickActionController` re-emits its own `state_changed` in response so the arena root's existing `state_changed → _refresh_hud` / `_refresh_danger` wiring keeps working without edits to `tick_arena.gd`.
- `TickActionController.state_changed` must keep firing for both existing reasons: a free action (Speed spend / Mobility Free Action refund) that changed meter/cooldown without advancing the world, and a message set/expiry. Refreshing danger on a message change is harmless and is preserved.
- Input-driven presentation stays in the verb methods and is NOT moved: `view.flash_deny` / `view.flash_swing`, `SmashFeedbackVFX.play_windup` / `play_impact`, and the smash windup/impact `AudioManager` calls. The boundary is outcome-driven (moves) vs input-driven (stays).
- `TickAimContext` owns the shared `TickActionPlanner` wrapping (mouse cell, aim direction, dash plan, smash-target clamp, chebyshev) and the RunBuild range projection via `TickCombatProjection` / `TickCombatRules`. Both controllers resolve exclusively through it. `TickActionController` owns `_last_aim` (mutated when an attack resolves); `TickPreviewController` reads it via `action_controller.get_last_aim()`. The context must read the current last-aim live at call time, never snapshot it, or preview and commit will drift.
- The grid/engine/player/run_build the aim context uses are the same instances the controllers already hold; construct the context after those are available (in each controller's `setup`, where `_run_build` arrives and the exported nodes are already wired).

## Scope

### Included

- Extract `TickCombatFeedback` (message timer/state, outcome→string mapping, major-trigger VFX/SFX); slim `TickActionController` to delegate via facade.
- Extract `TickAimContext`; route both controllers' aim/plan resolution through it.
- Add the feedback node to `tick_arena.tscn` and wire its exports.
- Add a focused `TickCombatFeedback` test; update the existing controller-verb test.

### Excluded

- Moving any `game/tick_arena/combat/` file into `common/gameplay/` (rejected: single consumer, `Tick*`-named policy is not a reusable primitive).
- Extracting a `TickEngine` actor/board contract or interface (rejected: no second implementation exists).
- Splitting action economy, the smash-cancel-confirm popup, or reward/wave/run ownership.
- Any change to player-facing behavior, tuning numbers, or the HUD text vocabulary.

## Files to Change

| File                                                | Change Size | Purpose                                                                                                       |
| --------------------------------------------------- | ----------- | ------------------------------------------------------------------------------------------------------------- |
| `game/tick_arena/combat/tick_combat_feedback.gd`    | Medium      | New. Owns message timer/state, outcome→string mapping, major-trigger VFX/SFX; emits message-changed.          |
| `game/tick_arena/combat/tick_aim_context.gd`        | Small       | New. Shared `TickActionPlanner` wrapping + RunBuild range projection, reading live last-aim.                  |
| `game/tick_arena/combat/tick_action_controller.gd`  | Medium      | Remove message/string/VFX bodies; delegate via facade; resolve aim through the shared context.                |
| `game/tick_arena/combat/tick_preview_controller.gd` | Small       | Replace private aim wrappers with the shared context.                                                         |
| `game/tick_arena/tick_arena.tscn`                   | Small       | Add `TickCombatFeedback` node; wire the controller's `feedback` export and feedback's `player` export.        |
| `game/tick_arena/tick_arena.gd`                     | None/Small  | No change expected if the facade is preserved; touch only if wiring the new node requires it.                 |
| `test/unit/test_tick_combat_feedback.gd`            | Small       | New. Cover message set/current/expiry and the outcome→string mapping table.                                   |
| `test/unit/test_tick_action_controller_verbs.gd`    | Small       | Wire a feedback collaborator into the context helper; move the message-state assertions to the feedback test. |

## Execution Outline

1. Add `TickCombatFeedback` with the message timer/state, `message_for_outcome(result) -> String` (the current `_apply_player_result_message` match, returning text instead of setting it), `report_hit_outcome(result, world_pos)` (major-trigger VFX/SFX then set message from the mapping), `set_message` / `current_message` / `append_suffix`, and a message-changed signal.
2. Add `test_tick_combat_feedback.gd` covering the mapping table (whiff, kill, execution, guard break, guard shredder, angle-named hit/block/burst) and message set/current — this is new coverage plus the relocated assertions from step 6.
3. Slim `TickActionController`: hold a `feedback` reference (exported, wired in the tscn); replace the two removed private methods so `_apply_player_hit` calls `feedback.report_hit_outcome(...)`; forward `set_message` / `current_message` to feedback and re-emit `state_changed` on the feedback message-changed signal; route the no-victim whiff and standalone notices through the feedback message path.
4. Add the `TickCombatFeedback` node to `tick_arena.tscn`, wire the controller's `feedback` export and the feedback node's `player` export; verify the arena root and run controller need no edits because the facade is intact.
5. Extract `TickAimContext`; construct it in each controller's `setup`; replace the five private aim/plan wrappers in both controllers with calls into it, reading last-aim live.
6. Update `test_tick_action_controller_verbs.gd`: wire an autofreed `TickCombatFeedback` into `_make_controller_context()` so message-posting verb paths do not null-deref; delete the message-state test now covered directly against feedback.
7. Run the tick unit suite and drive the arena (attack, dash, smash with and without victims, Guard Shredder / Execution hits, reward/reset/debug messages, message expiry) to confirm parity.

## Implementation Notes

- Facade discipline: `set_message` / `current_message` on the controller become one-line forwarders; do not leave a second copy of message state on the controller. `_append_message_suffix` moves to feedback as `append_suffix` (it reads the current message to append, so it must live where the message state lives).
- Route the no-victim mobility strike (`TickHitResolver.empty_outcome()`) through the message path only, not `report_hit_outcome` — an empty outcome has `MajorTrigger.NONE`, so no VFX should fire and there is no meaningful hit position.
- Feedback is a `Node` so its `_process` can drive message expiry in production; keep the timer-decrement step callable so a unit test can advance expiry without a scene tree. `message_for_outcome` must stay pure (only reads the outcome and `TickCombatRules.angle_name`) so it is testable without audio/VFX.
- For `TickAimContext`, prefer reading last-aim through a getter/callable the owner supplies rather than snapshotting it, since `TickActionController` mutates `_last_aim` when an attack resolves and the preview reads it every frame.
- New `.gd` files must follow `dev/standards/gdscript_structure_standard.md` and `dev/standards/naming_conventions.md` (file docstring header, `##` GDDoc on public methods); scene-node source rules follow `dev/standards/scene_node_source_standard.md`.

## Edge Cases

| Case                                              | Expected Handling                                                                                                          |
| ------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Mobility strike hits no enemy                     | Whiff message posts with no hit position; no major-trigger VFX.                                                            |
| Message expires the same frame the world advances | Both refresh the HUD; the result is idempotent, message clears once.                                                       |
| Bare-constructed controller in a unit test        | Only mode/aim/lock paths run bare; any message-posting verb path requires a wired feedback (the context helper wires one). |
| Grid not yet in tree (pre-spawn / unit test)      | Aim context falls back to `player.cell + last_aim`, exactly as the current wrappers do.                                    |

## Acceptance Criteria

1. Attacking, dashing, and smashing show the same HUD result text as before for every outcome (whiff, kill, execution, guard break, guard shredder, angle-named hit / block / burst).
2. Guard Shredder and Execution still play their distinct VFX and SFX on qualifying hits, layered over the base hit feedback.
3. Reward-applied, run-reset, cooldown, and debug mobility/trigger messages still appear in the HUD unchanged.
4. The HUD message still clears after its display duration and the HUD refreshes when it does.
5. Mobility previews (dash path and landing ghost, smash area, predicted outcome badges) still match what committing the same action resolves, with no preview/commit drift.
6. The full tick unit suite passes, and the outcome→string mapping plus message state have direct unit coverage.
