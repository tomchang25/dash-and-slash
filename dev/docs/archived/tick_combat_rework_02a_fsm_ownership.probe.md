**Enemy FSM ownership split**

Status: Archived probe.

Decision: resolved into dev/docs/plans/tick_combat_rework_02c_enemy_ownership.md — the FSM is deliberately narrowed to an intent/decision layer; clocked statuses move to a per-enemy tick combat runtime.

The enemy FSM problem is not tick clocking by itself. The friction is that behavior ownership became discontinuous during the tick conversion. `StateMachine` is still nominally the behavior-delegation layer, but many of the decisions that define enemy state now live in `TickEngine` and `GridEnemy`: detonation order, disabled status, recovery countdowns, telegraph freeze, and energy banking are all expressed outside the state scripts.

The result is a thinner FSM. Several states now look less like owners of enter/tick/exit behavior and more like labels that call an entity helper before moving to another label. That is workable for this conversion phase, but it weakens the main reason the project uses the state-machine framework: localizing behavior and transition rules inside state scripts.

- **State name vs runtime truth** — An enemy can remain in Telegraph state while the countdown and impact resolution are owned by `GridEnemy.resolve_detonation()`. The state name says "telegraph", but the state script is not the thing counting down, escalating, or resolving the attack.

- **Recovery as an external status** — Recovery state no longer owns the recovery timer. The engine status pass blocks action until `_recovery_ticks` ends, then the Recovery state advances back to idle on a later actor tick. That makes recovery partly an engine status and partly an FSM state.

- **Common rules are easy to bypass** — The ModeEnemy instant-facing issue was a symptom of the split. SmallEnemy and ChargeEnemy were moved to the current-facing capped-turn path, but ModeEnemy retained target-derived attack checks and a direct facing update during telegraph commit. Because the turn cap rule was not fully centralized in one owner, one kind could bypass it.

- **Transition ownership is blurred** — Some transitions are still state-driven with `change_state()`, while interrupts and lifecycle events use `request_transition()`, but core tick combat transitions also depend on external actor hooks called before state advancement. That makes it harder to tell whether the current state, the enemy base class, or the tick engine owns a behavior.

The discussion target is not "remove the FSM" by default. The target is to decide whether the FSM remains the primary behavior owner for tick enemies, or whether it becomes a lighter intent layer while tick combat status is owned by a separate runtime component. The current middle ground is the risky part.

Open question: should tick enemy states own more of the tick lifecycle directly, including telegraph countdown and recovery, or should the FSM be intentionally narrowed while a separate enemy tick runtime owns clocked statuses and attack resolution?

Open question: what invariant should prevent per-kind scripts from bypassing shared tick rules such as current-facing attack checks, disabled action gating, and no banked energy after guard break?
