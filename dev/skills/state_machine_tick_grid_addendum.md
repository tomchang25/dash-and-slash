# Tickstrike Tick-Grid State Machine Addendum

Read this project-local addendum together with `dev/skills/state_machine_pattern.md` before changing Tickstrike grid-enemy states, tick runtime, facing, or combat timing.

## Tick-Clocked Grid Enemies: The FSM Is An Intent Layer

Production grid enemies (`GridEnemy` and kinds) run the StateMachine with `frame_driven = false` and are advanced one `advance_tick()` per world tick by the `TickEngine`. For these enemies the FSM is deliberately narrowed to an **intent/decision layer**, not the owner of combat timing. Follow these rules when touching tick-enemy states:

- **States decide, they do not clock.** Surviving states are the ones that make a decision each tick: idle (plan and dispatch), reposition (step one planned cell), face-target (turn one capped step), the mode roll, plus the stagger and dead interrupts. There are no telegraph/attack/recovery "phase" states—those were removed. A committed attack or an open recovery window does not get its own state; the enemy stays parked in its deciding state while a separate runtime freezes it.
- **Clocked combat status lives in `EnemyTickRuntime`, not in states.** The committed attack's locked tiles, the player-action countdown to detonation, and the post-attack recovery window are owned by a per-enemy `EnemyTickRuntime`. The engine hooks (`resolve_detonation` / `advance_status` / `act_tick`) drive that runtime; a state never holds a `Timer` or counts ticks itself.
- **Commit inline, then park in idle.** A deciding state commits an attack by calling the entity's `try_commit_attack()` and then returning to idle. The runtime's freeze (while an attack is pending) and the recovery window cover the whole telegraph/detonation/recovery span, so the machine simply resumes deciding from idle when the window ends. When you remove a phase state that used a hand-off tick to return to idle, absorb that tick into the recovery count so post-attack timing is unchanged.
- **Only stagger and death use `request_transition()`.** Normal flow (plan → step → turn → commit → resume) is entirely `change_state()` from inside states. Entity code must not push the machine for attack/recovery lifecycle; those are runtime status, not transitions.
- **Facing changes go through the one capped funnel.** Tick-clocked facing flows only through `tick_turn_toward_cell()` (and the per-step facing of a one-cell move). Do not add instant-facing entry points—the per-tick turn cap is the flank-positioning cost and must be structurally impossible to bypass.
