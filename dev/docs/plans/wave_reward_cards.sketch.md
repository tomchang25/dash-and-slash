# Wave Reward Cards

## Goal

Turn the current wave sequence into an early roguelite run loop by offering card choices after each cleared wave, with terrain changes, enemy escalation, and a simple Major/Minor card split.

## Requirements

1. Clearing a wave pauses enemy spawning and presents three card choices so the player gets a deliberate build or map decision between combat beats.
2. Some choices are composed from two smaller rolled effects into one option, because combined options can create more interesting tradeoffs without requiring a huge card pool.
3. Terrain expansion lets the player add one connected land tile outward from the existing landmass so the arena can grow without creating isolated islands.
4. Terrain removal can randomly remove one valid land tile only if doing so keeps the landmass connected and does not remove active player, enemy, or reserved cells.
5. Enemy escalation can add one enemy to each future wave so the player can trade power or space against pressure.
6. Minor cards are pure numeric buffs and Major cards are major gameplay changes; the first Major card family is class change.
7. The first run structure uses base enemy counts of 2, 2, 3, 3, 4, 4, 5, 5, 6, then 6 plus a boss on wave 10.
8. Enemy types chosen or unlocked by earlier choices remain available in later waves, and each wave spawns its enemies at wave start.

## Design

This feature is the bridge from short arena demo to repeatable run. The first implementation should keep the card pool intentionally small: terrain add, terrain remove, future enemy count up, one or two Minor stat buffs, and one placeholder Major class-change card. A reward screen appears after every non-boss wave clear; choosing a card applies the effect, closes the reward screen, and starts the next wave.

Card categories:

| Category        | Meaning                     | First-pass examples                            |
| --------------- | --------------------------- | ---------------------------------------------- |
| Terrain option  | Changes playable land shape | Add connected land, remove safe connected land |
| Pressure option | Makes later waves harder    | Add one enemy to future waves                  |
| Minor card      | Pure numeric buff           | Damage up, dash cooldown down, max health up   |
| Major card      | Major gameplay change       | Class change placeholder                       |

Wave 10 is the first boss gate. Earlier waves should teach the loop before the boss arrives, so difficulty should rise through enemy count and accumulated card consequences rather than through many new rules.

## Sketch (non-normative)

Suggested card data shape:

```gdscript
{
    "id": "add_connected_land",
    "category": "terrain",
    "title": "Claim Land",
    "effects": [{ "kind": "add_land", "count": 1 }],
}
```

Suggested implementation steps:

1. Replace the fixed two-wave-plus-boss sequence with a 10-wave run counter using the base enemy count table.
2. After a wave clear, open a simple card reward overlay instead of immediately starting the next wave.
3. Roll three options from a small pool, allowing some options to combine two minor effects.
4. Apply the chosen card effect, then start the next wave.
5. Add connected-land selection for the terrain-add card.
6. Add safe random connected-land removal for the terrain-remove card.
7. Track future enemy count modifiers and apply them when spawning later waves.
8. Add a minimal Major/Minor category marker so class-change cards and numeric buff cards can diverge later.

## Non-Goals

1. No final card art, rarity system, deck-building economy, or persistent progression.
2. No complete class implementation beyond a placeholder or data path for Major class-change cards.
3. No advanced procedural island shaping beyond connected add/remove validation.
4. No mid-wave enemy spawning for normal waves; enemies spawn at wave start.

## Acceptance Criteria

1. Clearing a wave presents three card choices before the next wave starts.
2. Choosing a card applies exactly one option and then advances the run.
3. Add-land choices cannot place isolated land.
4. Remove-land choices cannot split the landmass or remove occupied, reserved, or player cells.
5. Future-wave enemy count increases affect later waves after the card is chosen.
6. The run reaches a boss wave on wave 10 using the base enemy count sequence plus accumulated modifiers.
7. Card choices can be identified as Major or Minor, with Minor cards limited to numeric buffs in the first pass.
