# Tick Arena Consolidation 04: Combat Contracts

Parent Plan: `tick_arena_structure_consolidation.md`

## Goal

Give tick combat one hit-angle vocabulary and typed cross-module contracts: the verb a player input emits and the outcome a hit resolves to become typed values instead of stringly-keyed dictionaries, so a typo'd key or missing default fails loudly instead of silently.

## Summary

- **Contract pressure:** Tick combat still has duplicate angle vocabulary and string-keyed verb/outcome payloads, which makes typo or missing-default bugs too easy to hide.
- **Likely direction:** Keep view-facing preview/danger dictionaries unchanged, but replace the combat-side angle, verb, and hit-outcome seams with typed values.
- **Verification focus:** The later spec must check the outside-`game/tick_arena/` blast radius around enemy hit prediction and take-hit paths before finalizing files and relationships.
- **Expected result:** Combat dispatch and hit consumption fail loudly through typed fields/enums, while feedback text, preview badges, and view payloads continue to behave the same.

## Sketch

1. Exactly one hit-angle enum exists across tick combat; the duplicate enum and its two-way adapter functions delete, because two identical vocabularies plus converters is pure ceremony.
2. Input verbs are typed values with an enum kind, so the action controller matches on an enum instead of `String(verb.get("type", ""))`.
3. Hit outcomes are typed values with named fields, so resolver, action controller, preview controller, and enemy pass-throughs stop re-deriving `bool(result.get(...))` with per-site defaults.
4. Match arms that return the same value for every branch collapse, and parameters that become dead after the collapse are removed rather than kept "for symmetry".
5. Tick hit resolution stops depending on a physics component's enum: the enemy-side take-hit path currently derives its is-dash flag from a hitbox guard-damage profile, and that flag becomes an explicit parameter of the typed contract, because tick logic reading legacy collision metadata is exactly the coupling this child exists to remove (carved out of the entity-layer legacy probe, which owns the rest of the physics-chain question).

Candidate implementation shape to verify:

- Adopt `DirectionResolver.HitAngle` as the sole angle vocabulary. `TickCombatRules.resolve_angle` / `guard_damage_for` / `hp_bypass_for` take and return it directly; delete `TickCombatRules.HitAngle`, `TickHitResolver._to_direction_angle`, and `_to_tick_angle`.
- `TickHitResolver._guard_damage_for` matches on hit kind but every branch returns the same expression — collapse to a direct call. That likely makes the `hit_kind` parameter of `resolve_hit` dead; verify the `GridEnemy.take_hit` / `predict_hit` call sites (they live outside `game/tick_arena/`) before removing it.
- New `TickVerb` (RefCounted or lightweight object): `kind` enum (`MOVE`, `CONFIRM`, `MODE_SET`, `CANCEL`, `WAIT`), `dir: Vector2i`, `mobility: bool`, `repeat: bool`. `TickInput` emits it; the action controller's `handle_verb` matches on the enum. The `{consumed, advances_world}` verb result can become a second tiny value type or stay a two-key dictionary — implementer's call, it never leaves the action controller.
- New `TickHitOutcome`: typed fields for `angle`, `was_guarded`, `staggered`, `guard_broken`, `stagger_burst`, `killed`, `hp_damage`, `guard_damage`, plus `feedback_kind` and `major_trigger` as enums replacing today's StringName constants. `TickHitResolver` returns it; `empty_outcome()` becomes a default-constructed instance.
- `GridEnemy.take_hit` / `predict_hit` currently pass the resolver dictionary through to the controllers — they convert to passing the typed outcome. This is the sketch's main outside-the-folder blast radius; the implementer walks those call sites and the enemy-side resolver usage on contact.
- The preview outcome badge entry (`{cell, label, tier}`), preview payload, and danger dictionaries stay as-is — view-facing display payloads, out of scope.

## Non-Goals

1. No change to any resolution rule, feedback text, or badge label.
2. No typing of view payload dictionaries.

## Acceptance Criteria

1. One hit-angle enum exists; no angle adapter functions remain.
2. Verb dispatch and hit-outcome consumption contain no string-keyed lookups with silent defaults.
3. All hit feedback messages, preview badges, and Major-trigger effects behave identically; lint and unit tests pass.
