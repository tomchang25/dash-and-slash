# Player Death & Restart Panel

## Goal

Replace the current bare "RUN OVER" text and input lock with a proper death banner that offers a single restart action, fix the run-end cleanup gap that leaves enemies and UI state alive underneath it, and add debug-only player-survival controls so the new death flow can be triggered and tested on demand.

## Requirements

1. On player death, show a death banner at the same visual weight as the existing wave-start banner (not a full modal card), replacing the current bare text label.
2. The banner exposes exactly one action, Restart. No mid-run continue option — death is final for a run.
3. Restart performs a full reload of the arena through the project's normal scene-entry path, rather than manually resetting and re-wiring the run's collaborators (wave/spawn state, reward state, HUD readouts) in place. A full reload is simpler and guarantees every run-scoped collaborator starts clean without a second reset path to keep in sync.
4. Run-end cleanup must force-kill/despawn every enemy still alive and disconnect any per-elite signal listeners taken out for the current run, because today only the old finite-boss-run path did this — the current infinite-wave run-end path leaves survivors pathing/attacking an input-locked player and can leave the boss-guard readout stuck on screen. This must land together with the death panel, since the panel is what makes a still-"live" battlefield directly visible to the player.
5. Add a debug-only player god-mode control that cycles through three mutually exclusive states — Off, Undead, No-Damage — as a single toggle whose current state is always visible.
6. Add a debug-only Instant Kill action for the player, independent from the god-mode toggle, so death (and the new banner) can be triggered on demand without waiting for a real lethal hit.

## Design

### Death banner & restart

The death banner reuses the wave-start banner's visual treatment (same overlay/backdrop weight) but does not auto-dismiss — it stays on screen and carries a Restart action that the wave-start banner doesn't have. Input remains locked on death, as it is today; the banner simply replaces the "RUN OVER" text.

Pressing Restart re-enters the arena the same way any other entry into the arena works. Because the whole scene is rebuilt from scratch, every run-scoped collaborator — wave number, spawn queue, alive enemies, reward state, HUD readouts — resets naturally. No run state carries over between one run and the next.

### Run-end cleanup (bug fix riding along)

Run end becomes real cleanup, not just "stop spawning":

- Every enemy still alive at the moment the run ends is force-killed/despawned so nothing keeps acting against an input-locked player.
- Any signal listeners wired specifically for the current elite (e.g. its guard-changed readout) are disconnected as part of this same cleanup, instead of only being torn down when an elite dies through its normal clear path.
- The boss-guard readout is force-hidden on run end unconditionally, not only when the elite-cleared path fires naturally.

### Player god-mode debug states

Three mutually exclusive states, advanced by repeated activation of one control:

1. **Off** (default) — normal damage and death rules apply.
2. **Undead** — incoming damage still reduces HP and still plays the normal hit feedback (sfx, hit flash, invulnerability blink), but HP is floored at 1: it can never reach 0, and death never fires, regardless of how much damage lands or how many hits land.
3. **No-Damage** — incoming damage plays the full normal hit feedback (sfx, hit flash, invulnerability blink) exactly as if it landed, but HP itself is left completely unchanged; the hit is cosmetic only.

Switching states is instant and never retroactively applies: leaving Undead while sitting at 1 HP does not kill the player, and leaving No-Damage does not apply any damage that was suppressed while it was active.

God mode does not persist across a restart — every new run begins Off, consistent with restart being a full reload. A debug user re-enables it per run if needed; no separate persisted debug preference is in scope here.

### Instant Kill (debug)

Instant Kill is a one-shot action, not a fourth god-mode state:

- With god mode Off, Instant Kill immediately reduces the player to 0 HP and fires the normal death flow, exercising the exact same path a real lethal hit would (including the new death banner).
- With god mode Undead or No-Damage active, Instant Kill is a no-op, exactly like a real lethal hit is already suppressed under those states. This keeps the god-mode contract honest — Instant Kill is not a secret way around the mode currently selected, so a tester who wants to force a death must first switch god mode back to Off.

## Non-Goals

1. No mid-run continue or respawn option on the death panel — Restart is the only path back into a run.
2. No persistence of run stats, currency, or meta-progression across a restart; a full reload means every run starts clean, and no such persistent system exists yet.
3. No changes to the reward-choice panel or wave-start banner behavior beyond reusing the wave-start banner's visual weight as a reference for the death banner.
4. God mode and Instant Kill are debug-only tools; this is not a player-facing difficulty or accessibility toggle.
5. No enemy-side god mode or invulnerability — the survival debug controls are player-only.

## Acceptance Criteria

1. Player death shows a banner at the same visual weight as the wave-start banner, with a single Restart action, and none of the old bare "RUN OVER" text remains.
2. Pressing Restart returns to a fully fresh run: wave number, alive enemies, spawn queue, reward state, and HUD readouts all start clean, with nothing left over from the previous run.
3. On any run end — a real lethal hit or a debug Instant Kill — no enemy remains alive or acting afterward, and the boss-guard readout is hidden even when the run ends outside a milestone wave's natural elite-cleared path.
4. With god mode Off, damage and death behave exactly as before this change.
5. With god mode Undead, HP visibly drops and hit feedback (sfx/flash/blink) plays on every hit, but HP never reaches 0 and death never fires, regardless of hit count or damage size.
6. With god mode No-Damage, hit feedback (sfx/flash/blink) plays on every hit, but the HP readout never changes.
7. Instant Kill triggers the full death flow, including the new banner, when god mode is Off, and produces no observable effect when god mode is Undead or No-Damage.
8. All three god-mode states and Instant Kill are inert and inaccessible whenever debug mode is off, consistent with how other debug-only actions in the project are gated.
