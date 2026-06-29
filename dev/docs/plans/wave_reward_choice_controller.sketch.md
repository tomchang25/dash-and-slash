# Wave Reward Choice Controller

## Goal

Add the runtime reward-choice flow that appears after normal waves, rolls three random card options, applies the selected option immediately, and hands control back to the wave flow.

## Requirements

1. Clearing a normal wave opens a reward choice overlay instead of immediately starting the next wave.
2. The reward offer contains three random choices from the current reward pool.
3. Choosing one card applies that card once, closes the reward overlay, and resumes the next wave.
4. Terrain reward effects resolve immediately by randomly choosing a valid terrain cell, because the first pass intentionally avoids tile targeting UI.
5. The controller keeps only ephemeral choice state and delegates durable effects to the terrain, wave, or player-stat owners.

## Design

The choice flow is a small pause between combat beats. The player is not choosing a target cell, ordering effects, or storing cards for later. A card is either applicable now or filtered out before the offer is built.

Terrain add candidates are sea cells adjacent to current land. Terrain remove candidates are land cells that pass active-state safety and connected-land validation. If a terrain card has no valid candidates, it should not appear in the rolled offer.

Combined options may appear as a single choice with two smaller effects once basic single-effect cards are stable. Combined options still count as one selected reward and apply atomically from the player's point of view.

## Sketch (non-normative)

Suggested runtime shape:

```gdscript
var _current_offer: Array[WaveRewardCard] = []

func open_reward_choice() -> void:
    _current_offer = _reward_pool.roll_choices(3)
    _reward_overlay.show_choices(_current_offer)


func _on_reward_selected(card: WaveRewardCard) -> void:
    _reward_applier.apply(card)
    _current_offer.clear()
    _reward_overlay.hide()
    _wave_controller.start_next_wave()
```

Suggested card shape:

```gdscript
{
    "id": "claim_land",
    "category": "terrain",
    "tier": "minor",
    "title": "Claim Land",
    "effects": [{ "kind": "add_random_connected_land", "count": 1 }],
}
```

Suggested terrain effect helpers:

```gdscript
func _get_add_land_candidates() -> Array[Vector2i]:
    # Sea cells with at least one orthogonal land neighbor.


func _get_remove_land_candidates() -> Array[Vector2i]:
    # Land cells where can_remove_land(cell) is true and simulated removal keeps remaining land connected.
```

Migration steps:

1. Add a reward choice flow entry point that the wave flow calls after normal wave clear.
2. Add a simple reward overlay with three selectable card buttons.
3. Add reward rolling from the first small pool: add land, remove land, future enemy up, one or two Minor stat buffs, and one Major placeholder.
4. Add an applier that dispatches each effect to the terrain, wave, or player-stat owner.
5. Filter out terrain cards with no valid candidates before showing the offer.
6. Resume the next wave only after a card is selected and applied.

## Non-Goals

1. Do not implement tile targeting, placement preview, or cancel flow.
2. Do not implement reward persistence between runs.
3. Do not implement full card art, rarity, or deck construction.

## Acceptance Criteria

1. A normal wave clear opens a three-card reward choice.
2. Selecting a card applies it once and starts the next wave.
3. Terrain choices apply immediately to a randomly selected valid cell.
4. Cards with no valid immediate effect are not offered.
5. The reward controller does not become the durable owner of terrain, wave, or player-stat state.
