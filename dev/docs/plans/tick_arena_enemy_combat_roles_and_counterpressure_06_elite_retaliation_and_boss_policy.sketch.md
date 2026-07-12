# Tick Arena Enemy Combat Roles And Counterpressure 06: Elite Retaliation And Boss Policy

Parent Plan: `tick_arena_enemy_combat_roles_and_counterpressure.md`

## Goal

Give Mode enemies a visible post-Stagger retaliation cycle while preserving per-boss freedom to replace the elite rule with bespoke phase behavior.

## Summary

Mode receives the shared five-tick protection and empowers its next committed attack after Stagger recovery. The attack snapshots one fewer warning tick with a floor of one and a 1.25 damage multiplier, then consumes the empowerment on resolve or cancellation. Bosses may opt into the same policy but are not required to inherit it.

## Sketch

- Empowerment should be runtime combat-cycle state, not a passive state-machine label. A dedicated behavior state is justified only if the enemy performs a real rally action such as a visible turn or roar.
- Warning and damage modifiers must snapshot at commit so an already visible countdown never accelerates. All danger displays and outgoing-damage previews should read the committed values.
- Mode already changes attack selection around Stagger recovery; verify the order between selection, protection start, empowerment presentation, facing response, and next commit so the retaliation cannot be silently lost.
- Cancellation through death, reset, or an explicit attack-cancel path must clear empowerment consistently. Ordinary pathing delay should not consume it before an attack commits.
- Boss policy should be authored per encounter: reuse default Mode retaliation, replace it with a custom phase response, or omit it. The placeholder Boss may reuse Mode behavior until a bespoke design exists.
- Candidate files to inspect include Mode combat-cycle selection, shared attack runtime, Guard recovery signals, attack timing and damage projection, visual presenters, placeholder Boss content, and focused snapshot/cancellation tests.

## Non-Goals

1. Do not implement a bespoke final boss, multi-phase health gates, summons, or new boss attacks.
2. Do not apply Enrage to Small, Heavy, Bomb, or Ranged roles.
3. Do not alter an attack countdown after it has been shown to the player.

## Acceptance Criteria

1. Mode visibly empowers exactly its next committed post-Stagger attack with one fewer warning tick and 1.25 damage.
2. Empowerment survives pathing until commit, snapshots its values, and clears exactly once on resolution, cancellation, death, or reset.
3. Boss content can choose a default or custom post-Stagger policy without changing shared Mode behavior.
