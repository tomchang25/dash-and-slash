# Minor Wave Reward Cards

## Goal

Add the first Minor reward cards as numeric player buffs that make reward choices immediately meaningful while keeping card effects simple and data-driven.

## Requirements

1. Minor cards only apply numeric stat changes.
2. The first Minor pool includes damage up, attack speed up, dash damage up, dash cooldown down, and max health up.
3. Minor cards use the player-stat data path instead of directly mutating unrelated systems.
4. A Minor card can be combined with another small effect later, but the first implementation must support single Minor cards clearly.
5. Minor effects should be readable in the reward UI through title and concise effect text.

## Design

Minor cards are the low-risk, high-frequency reward type. They should be easy to reason about and safe to combine later. The category boundary is strict: if a card changes input, attack shape, class, movement rules, terrain, enemy pool, or wave structure, it is not a Minor stat card.

First-pass examples:

| Card           | Effect                              |
| -------------- | ----------------------------------- |
| Sharpened Edge | Normal attack damage up             |
| Quick Hands    | Normal attack cooldown down         |
| Impact Dash    | Dash attack damage up               |
| Light Footwork | Dash cooldown down                  |
| Vital Spark    | Max health up and current health up |

## Sketch (non-normative)

Suggested card entries:

```gdscript
{
    "id": "minor_normal_damage_up",
    "tier": "minor",
    "category": "player_buff",
    "title": "Sharpened Edge",
    "description": "Normal attack damage up.",
    "effects": [{ "kind": "add_normal_attack_damage", "value": 2.0 }],
}
```

Suggested supported stat ids:

```txt
normal_attack_damage
normal_attack_cooldown
dash_attack_damage
dash_cooldown
max_health
```

Migration steps:

1. Add first-pass Minor card definitions.
2. Add UI text rendering for title and effect summary.
3. Route Minor effects through the player-stat owner.
4. Keep Minor card selection compatible with the generic reward-choice flow.

## Non-Goals

1. Do not add non-numeric Minor cards.
2. Do not add rarity, scaling tiers, or weighted rolls in this slice.
3. Do not implement weapon class attacks through Minor cards.

## Acceptance Criteria

1. Minor cards can appear in the three-card reward offer.
2. Selecting a Minor card applies a numeric player stat change.
3. The reward UI communicates the card title and effect.
4. Minor card logic does not own player stat state directly.
