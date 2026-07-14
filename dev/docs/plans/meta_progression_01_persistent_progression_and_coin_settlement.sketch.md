# Meta Progression 01: Persistent Progression And Coin Settlement

Parent Plan: `meta_progression.md`

## Goal

Explore the persistent profile and terminal run-settlement foundation that later character selection and artifact purchases will consume. This slice should persist Coin and demo completion, award Coin exactly once from a finalized run outcome, and extend the basic results surface without yet building Main Menu unlock interactions.

## Summary

The favored shape is one global progression owner that registers with the existing save coordinator and owns all persistent progression state. The run controller should remain scene-local: it creates a terminal outcome once, while the progression owner consumes that outcome to calculate and persist Coin.

Wave 10 completion and terminal settlement are distinct events. Clearing wave 10 as Ninja should immediately and idempotently record demo completion and Viking's unlock, while `Continue Endless` keeps the run active without paying Coin. Death or `End Run` later finalizes the run once and awards Coin for every completed wave represented by the outcome.

The later implementation spec should verify the live result-overlay seam created by Wave Progression Child 02 before choosing exact files or signatures. It should also choose initial payout values as authored tuning while preserving the fixed behavioral rule: higher completed waves pay more and every fifth completed wave adds a bonus.

## Sketch

- A candidate persistent owner is a project-wide progression store registered before normal save loading. It would own non-negative Coin balance, demo-completion state, unlocked character IDs, and unlocked artifact IDs even though this child exposes only the completion and Coin mutations needed by the first slice.
- The save section should carry its own version and use missing-field defaults for a new or older payload. Candidate defaults are zero Coin, Ninja unlocked, Viking locked, demo incomplete, and a baseline artifact-unlock set supplied by the later artifact child.
- The save coordinator should remain orchestration only. The progression owner should serialize, restore, validate, migrate its section, and expose guarded mutations so UI or run code cannot edit collections and balances directly.
- A candidate run-outcome value should carry a unique run-local settlement identity, terminal reason, selected character ID, highest completed wave, and demo-completed flag. Verify whether Child 02 establishes this as a typed value or an immutable dictionary before the later spec freezes the contract.
- Wave clear should update highest completed wave before any wave-end reward or completion branch. Settlement therefore consumes an already-final outcome and should never add one based on terminal reason.
- Death and `End Run` should call one finalization path. That path should reject a second finalization for the same run before showing or reusing the result, then hand the outcome to progression and render the returned payout summary.
- `Continue Endless` should neither finalize nor award Coin. If the player later dies during wave N, the outcome should include N - 1 and the settlement should award waves 1 through N - 1 once.
- Coin calculation should be a deterministic pure projection from highest completed wave plus authored payout tuning. It should sum a strictly increasing positive base reward for each completed wave and an additional reward at every wave divisible by five, returning both total payout and enough breakdown data for the result overlay to explain base and milestone Coin.
- Candidate authored payout data could live beside the meta-progression domain rather than in combat wave definitions, because Coin economy may change without changing encounter data. The later spec should prefer the smallest validated shape that keeps payout and fifth-wave bonus values out of the run controller.
- Clearing wave 10 as Ninja should immediately call an idempotent progression mutation that marks demo completion and unlocks Viking, then persist before the `End Run` / `Continue Endless` branch appears. Clearing with another character or repeating the event should not grant a second unlock-side effect.
- The result overlay should add earned Coin and resulting total Coin to the basic outcome fields from Child 02. `Restart` starts a fresh run identity; `Return to Main Menu` routes normally after the save-backed award has completed.
- Save failure should leave the in-memory award applied and surface an error through the established save path; repeated UI input in the same live run must still not award twice. Cross-process exactly-once recovery is outside scope because active run identities are not persisted.
- Candidate files to inspect: the save coordinator and boot autoload order, a new progression owner and its focused tests, the run outcome/finalization seam and results overlay delivered by Wave Progression Child 02, scene routing back to the Main Menu, and authored meta-progression payout data.

## Non-Goals

1. No Main Menu character picker or locked-character UI; Child 02 owns that surface.
2. No Artifact shop, prices, baseline artifact selection, or reward-pool filtering; Child 03 owns those behaviors.
3. No active-run save, resume, crash recovery, or payout after application exit without a terminal outcome.
4. No final Coin economy balance or long-term price curve.
5. No direct permanent combat-stat bonuses.

## Acceptance Criteria

1. One save-backed progression owner retains Coin, demo completion, and unlock identities across restart with safe defaults and versioned migration behavior.
2. Death and `End Run` use one terminal outcome and award the same deterministic Coin result for the same highest completed wave.
3. An unfinished current wave awards nothing, while every completed fifth wave contributes its additional configured bonus.
4. Repeated finalization, result interaction, or completion notification cannot award the same run or unlock Viking more than once.
5. Clearing wave 10 as Ninja persists demo completion and Viking's unlock before the player chooses whether to end or continue.
6. `Continue Endless` pays no Coin, and a later death settles the entire run through its final highest completed wave exactly once.
7. The results surface explains the terminal outcome, earned Coin, and resulting total before restart or return to Main Menu.

