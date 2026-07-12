# Meta Progression

## Goal

Add a small persistent progression loop that turns completed runs into Coin, uses the first Ninja demo clear to unlock Viking, and lets players spend Coin to expand the artifact pool available during future runs. The loop should give every run lasting value without allowing menu progression to mutate active combat state.

## Requirements

1. A run awards Coin only when it reaches a terminal settlement through death or `End Run`; abandoning the application or choosing `Continue Endless` does not settle because active-run checkpointing is outside this feature.
2. Coin reward is based only on completed waves, increases with wave number, and grants an additional bonus for every fifth completed wave so deeper runs are more valuable without counting a wave merely entered before death.
3. The first Ninja clear of wave 10 permanently records demo completion and unlocks Viking immediately, before the player chooses `End Run` or `Continue Endless`, so the unlock cannot be lost by continuing into endless play.
4. The Main Menu must let the player choose an unlocked character before starting a run, show Viking as locked until its requirement is met, and prevent locked or invalid selections from entering gameplay.
5. Coin can permanently unlock authored artifacts from the Main Menu; unlocked artifacts join the normal reward candidate pool but must still pass rarity, wave, character-mobility, ownership, exclusivity, and capacity rules.
6. Persistent progression must survive restart and tolerate missing or older fields through versioned defaults and append-only migrations, because player save compatibility is part of the feature rather than an implementation detail.
7. Run settlement must be idempotent so repeated signals, overlay actions, or navigation cannot award the same run twice.

## Design

### Run outcome and settlement

The combat run produces one terminal outcome containing its end reason, selected character, highest completed wave, and whether the demo was completed. Death and `End Run` differ only in why the outcome was produced; both use the same Coin calculation and persistence path.

The highest completed wave is updated when a wave clears, before reward or completion presentation. Dying during wave 5 therefore settles waves 1–4, clearing wave 10 and choosing `End Run` settles waves 1–10, and continuing after wave 10 before dying during wave 14 settles waves 1–13. `Continue Endless` does not create a partial settlement.

Each completed wave contributes an authored positive base amount that strictly increases by wave number. Every completed wave divisible by five contributes an additional authored bonus. The settlement sums all eligible wave rewards from wave 1 through the outcome's highest completed wave; final economy values remain tuning data rather than hardcoded combat rules.

One run may settle at most once. Restart begins a new settlement identity, while reopening or reusing the prior result cannot add Coin again. Because active runs are not saved, closing the application before a terminal outcome forfeits that run's unsettled Coin.

### Persistent profile

One persistent profile owns the Coin balance, demo-completion state, unlocked character identities, and unlocked artifact identities. It is the only authority allowed to grant or spend Coin or change unlock state. The save coordinator serializes this owner but does not duplicate its gameplay state.

Ninja is always available. Clearing wave 10 as Ninja permanently records demo completion and unlocks Viking immediately even when the player continues into endless mode. Repeating the clear is harmless and does not duplicate an unlock or Coin payout.

Coin balance never becomes negative. An unlock purchase succeeds only when the target exists, is currently locked, and the profile can afford its authored cost; a failed purchase leaves both balance and unlock state unchanged.

### Main Menu and run entry

The existing Main Menu expands from a neutral Play entry into the pre-game character and progression surface. It remains outside combat ownership: it reads the persistent profile, selects an allowed character, and routes that identity into a newly created arena run.

Locked characters remain visible with their unlock requirement. The arena validates the incoming selection against authored character content and the persistent profile, falling back to Ninja with a visible development error if navigation data is missing or invalid.

### Artifact unlock pool

Artifact progression uses authored identities and costs. A small baseline set is unlocked by default so a new profile can receive valid reward offers; purchases add artifacts to the unlocked set permanently.

Permanent unlock is an additional eligibility gate, not a replacement for run-time reward rules. An unlocked Viking-specific artifact still cannot appear for Ninja, an artifact below its minimum wave still waits, and a unique artifact already owned during the current run remains ineligible.

If the unlocked pool cannot fill an offer, the existing smaller-offer or disabled-choice fallback remains explicit rather than silently borrowing locked artifacts. Initial baseline composition, unlock prices, and long-term economy tuning belong to the artifact-unlock child rather than the persistence foundation.

### Child overview

| Child | Focus | Current document |
| ----- | ----- | ---------------- |
| 01 | Persistent profile, unified terminal Coin settlement, immediate demo completion, and results integration | `meta_progression_01_persistent_progression_and_coin_settlement.sketch.md` |
| 02 | Main Menu character selection, locked Viking presentation, and validated arena hand-off | Not started |
| 03 | Artifact unlock catalog, Coin purchase UI, default pool, and reward eligibility integration | Not started |

Recommended landing order: establish saved progression and settlement first, then make character selection consume that truth, then add artifact purchases and reward-pool filtering after both the profile and Main Menu surface are stable.

## Non-Goals

1. Do not save or resume an active run, recover unsettled Coin after application exit, or checkpoint endless progress.
2. Do not add characters beyond Ninja and Viking or change their combat kits.
3. Do not add artifact rarity odds, random shop inventory, refunds, respec, repeatable purchases, or dynamic pricing.
4. Do not finalize Coin payout values, artifact prices, or long-term economy balance in the persistence foundation.
5. Do not let permanent progression directly increase player or enemy combat stats outside the artifacts made eligible for normal run rewards.

## Acceptance Criteria

1. Death and `End Run` settle through one path, count only completed waves, include every fifth-wave bonus, and cannot award the same run twice.
2. Coin, demo completion, character unlocks, and artifact unlocks survive a restart with safe defaults for a new or older save.
3. Clearing wave 10 as Ninja unlocks Viking before the end-or-continue choice, and continuing into endless play neither revokes nor duplicates that unlock.
4. The Main Menu blocks Viking before unlock, allows Ninja by default, and starts the arena with the selected unlocked character.
5. Spending Coin on an artifact atomically reduces the balance and permanently unlocks it; invalid or unaffordable purchases change nothing.
6. Reward offers draw only from permanently unlocked artifacts that also satisfy every existing run-time eligibility rule.
7. Losing during an unfinished wave never awards that wave, while completing waves 5, 10, 15, and later fifth-wave boundaries includes their configured bonuses.

