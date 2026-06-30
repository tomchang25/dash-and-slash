# Major Wave Reward Card Skeleton

## Goal

Add enough Major-card structure for the reward system to distinguish structural gameplay cards from Minor stat buffs without implementing real class changes yet.

## Requirements

1. Reward cards can be marked as Major or Minor.
2. Major cards can appear in the reward pool and be selected through the same choice flow.
3. The first Major family is class change, represented as a placeholder effect only.
4. Selecting the placeholder Major card records or displays that the effect resolved without changing weapon attacks or player class behavior.
5. Major-card plumbing must not force the weapon/class attack variant work into this phase.

## Design

Major means structural change potential, not rarity. A Major card may later change class, weapon action set, movement rules, or other large gameplay contracts. This phase only needs the category boundary and safe placeholder path so later class-change work can plug in without reshaping the reward system.

The placeholder class-change card should be honest in UI copy. It can say that class change is not implemented yet, or it can use prototype language that makes the card visibly non-final during development.

## Sketch (non-normative)

Suggested placeholder card:

```gdscript
{
    "id": "major_class_change_placeholder",
    "tier": "major",
    "category": "class_change",
    "title": "Class Shift",
    "description": "Prototype Major card. Class behavior is not implemented yet.",
    "effects": [{ "kind": "class_change_placeholder" }],
}
```

Suggested applier branch:

```gdscript
func _apply_class_change_placeholder(_effect: Dictionary) -> void:
    # Mark resolved for now. Real class behavior belongs to a later class/weapon plan.
```

Migration steps:

1. Add Major/Minor tier metadata to reward card definitions.
2. Add one placeholder Major class-change card.
3. Make the reward UI display Major cards distinctly enough for development validation.
4. Add an applier branch that resolves the placeholder without changing player action behavior.
5. Keep real class behavior and attack variants deferred.

## Non-Goals

1. Do not implement real class switching.
2. Do not implement weapon attack variants.
3. Do not add Major-card rarity or guaranteed-roll rules.
4. Do not persist class state beyond the current placeholder behavior.

## Acceptance Criteria

1. Reward cards can be identified as Major or Minor.
2. A placeholder Major class-change card can appear and be selected.
3. Selecting the placeholder Major card resolves safely without changing player attacks.
4. Weapon/class attack variant work remains out of this phase.
