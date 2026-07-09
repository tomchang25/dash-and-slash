# Tick Arena Visual Readability 04: Character Classes

Parent Plan: `tick_arena_visual_readability_and_identity.md`

## Goal

Explore character classes as bundled starting identities for tick verbs after enemy readability has a stable visual runtime and baseline enemy body language: each class should define Speed feel, normal attack shape, default mobility payload, a class-locked perk, and a clear weapon/aim marker.

## Summary

Character classes should not revive the old weapon-class idea as hitbox variants alone. A class is a starting combat identity centered on one main mobility fantasy. The first candidate set remains kunai/ninja, katana/samurai, and heavy axe, but the later spec should verify combat data seams before freezing names or numbers.

Codebase context gathered so far suggests the tick player has no combat facing, Speed meter is an explicit player-owned meter, normal and mobility damage/range/cooldown are projected from run build channels, and mobility payload already supports Dash versus Smash replacement. That means classes should probably configure starting values and default verbs without adding hidden variable action costs.

The player visual contract should not be copied directly from enemy visuals. Player presentation can reuse a low-level sprite-frame animator if child 01 creates one, but the player needs an aim marker rather than combat-facing body direction.

## Sketch

- Candidate class dimensions: base Speed fill profile, normal attack cell shape, default mobility payload, one class-locked perk, and one weapon/aim marker that points at current mouse aim.
- Kunai/ninja candidate: fast Speed fill, line-thrust normal attack, Dash default, perk around chain dash, kill refund, or stronger back-hit flow.
- Katana/samurai candidate: balanced Speed, arc or short-wide normal attack, Dash default, perk around guard/counter timing or stronger punish after guard break.
- Heavy axe candidate: slow Speed, wide normal attack, Smash default, perk around stagger burst, shockwave, or stronger area guard damage.
- The player body should not gain combat facing. The marker reads aim direction, because player attacks are aimed by mouse/quadrant rather than body orientation.
- Classes should make future Major effects more coherent by collecting them under mobility fantasies instead of expanding a generic pool of unrelated upgrades.
- The later spec should verify whether class data belongs as a new starting-loadout resource, run-start selection, or temporary debug selection. It should also verify how normal attack shape can change without breaking preview honesty.
- Avoid hidden fractional action costs. Slower/faster class feel should use explicit Speed fill, cooldown, windup, or clear action-shape tradeoffs.

## Non-Goals

1. No full character selection UI in this sketch.
2. No final class balance numbers.
3. No permanent progression or unlock economy.
4. No enemy pattern work in this child.

## Acceptance Criteria

1. Each class concept reads as a bundled starting identity, not merely a cosmetic weapon skin.
2. Class differences center on mobility fantasy, Speed feel, attack shape, and one locked perk.
3. The player marker communicates aim without implying combat facing.
4. Future Major effects have a clearer home inside class fantasies instead of becoming generic build soup.
