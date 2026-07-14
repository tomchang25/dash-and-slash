# Enemy Action Commitment, Multi-Step Movement, And Replanning

## Goal

Make every enemy-phase opportunity produce one useful, readable action while treating an attack's visible warning as its counterplay window. Normal attack setup no longer pays a separate facing action, fast movement belongs to one bounded multi-step MoveAction instead of multiple actions in one phase, and movement conflicts no longer collapse into avoidable idle churn.

## Requirements

1. An enemy that can establish valid attack geometry from its current cell must turn and commit that attack in the same enemy action, because the visible warning already gives the player a complete round to reposition or flank.
2. Oriented attacks must lock their direction and affected cells at commitment and never retarget during warning, while symmetric attacks lock their center and footprint without inventing a facing dependency.
3. Each enabled enemy may resolve at most one action in an enemy phase; a MoveAction may traverse its authored number of cells step by step and then commit a valid warning on arrival, but no action may detonate an attack that it just committed.
4. Normal planning must not spend an enemy action only entering a movement, facing, or attack-intent state; internal decisions may chain until the enemy completes its one MoveAction, commits a warning, or proves that no legal action exists.
5. Losing a reserved path step or finding the next step blocked must trigger one immediate bounded replan inside the same MoveAction, using only the remaining movement budget, so a transient ownership conflict does not automatically waste the whole action or grant extra distance.
6. A qualifying damaging player hit must resolve its capped facing response immediately after that hit's angle is determined and without consuming an enemy action; each eligible hit may turn at most 90 degrees, while commitment, Stagger, and death suppress the response so locked warnings and disabled enemies remain visually stable.
7. A newly spawned enemy's first funded action must use the same decision contract, so spawn timing never adds an extra state-transition-only delay before movement or commitment.

## Design

### Committed attack lifecycle

Enemy attack behavior is one committed lifecycle: establish geometry, turn toward the committed direction when the attack is oriented, lock the footprint, display its warning, detonate the locked footprint, then recover. Warning and final attack presentation may use different visual phases, but they are not separate enemy decisions and do not require an earlier facing action.

A one-round Small Enemy warning is therefore its short Windup: after commitment, the player receives one complete AP round before detonation. Longer attacks keep their authored warning lengths. The separate action-point timing contract owns round advancement and countdown presentation; this plan owns what the enemy may do when its enemy-phase opportunity arrives.

The player can exploit warning and recovery to reach side or back angles, and moving out of a locked footprint causes the committed attack to miss. The player cannot cancel commitment merely by changing the live angle after the attack has already locked.

### Facing after player hits

Facing remains mechanically relevant as an immediate hit response and as the orientation captured by an attack at commitment. After the current hit resolves against the pre-hit facing, an eligible enemy turns at most 90 degrees toward the attacker for no enemy-action cost. A full 180-degree reversal therefore requires a second eligible hit, which may occur in the same player round only by spending another AP. A committed warning, Stagger, or death suppresses the response so the attack's presentation and locked orientation cannot diverge.

### Enemy action resolution

One enemy action may perform internal planning and state transitions without charging time for those labels. A MoveAction receives an authored step budget, traverses its route one cell at a time, and may commit a warning if its final resolved cell supplies valid attack geometry. Movement steps are subdivisions of that one action rather than additional actions, and the action ends immediately on commitment so no newly committed attack can detonate in the same enemy phase.

Every movement step must resolve against current land, occupancy, and reservation truth; ordinary movement cannot pass through the player, another enemy, or a blocking actor. When the next intended step is unavailable, the enemy discards stale reservations and replans once from its current cell with only the unspent step budget. A successful retry may continue and commit under the normal limits. A failed retry stops in the last legal cell and ends the action; the bounded retry prevents an internal loop when several enemies contest the same region.

Enemy speed identity uses authored distance and timing rather than several independent actions in one phase. Standard movement may remain one cell, an assassin-style MoveAction may traverse two cells, and attack warning or recovery values express how quickly the role converts position into damage and how long it rests afterward. Slower roles may continue to skip phases through bounded action funding, but no enemy may bank or spend more than one action in a single enemy phase.

### Child overview

| Child | Focus | Current document |
| ----- | ----- | ---------------- |
| 01 | Facing-free attack commitment and immediate hit-facing response | Not started |
| 02 | Multi-step MoveAction, same-action decision chaining, and bounded replanning | Not started |
| 03 | First-action behavior and cross-role regression coverage | Not started |

Recommended landing order: first establish the separate player-round and AP boundary; then remove the normal facing tax and establish the committed lifecycle plus immediate hit response; add multi-step movement and bounded replanning next; finally validate first-action behavior across newly spawned melee, ranged, charge, bomb, and multi-mode enemies.

## Non-Goals

1. Do not redesign player AP costs, AP rewards, Chain Dash overflow, or Telegraph countdown presentation; the separate action-point timing plan owns those rules.
2. Do not change authored warning or recovery lengths as part of removing the facing tax.
3. Do not change attack footprints, damage, spawn composition, or wave scaling.
4. Do not remove facing from Guard angle resolution or player side/back attack rewards.
5. Do not give ordinary multi-step movement Charge-style collision damage, forced displacement, actor traversal, or teleportation.

## Acceptance Criteria

1. A Small Enemy with valid attack geometry commits immediately, presents its one-round Windup, and detonates only after the next complete player round.
2. Ranged and Charge enemies commit from valid geometry without a separate facing action, then resolve only their locked footprint even if the player moves elsewhere.
3. The player can still earn side and back attacks during warning and recovery, while moving after commitment cannot force the enemy back into pursuit or facing setup.
4. One enemy action may traverse its authored one- or multi-cell movement budget and commit on final arrival, but it never becomes two independent actions or detonates a newly committed attack in the same enemy phase.
5. A stolen or blocked path step receives one immediate replan attempt within the remaining movement budget, and every resolved step leaves reservation and occupancy state consistent.
6. A qualifying hit resolves against the pre-hit angle and then turns an eligible enemy by at most 90 degrees immediately without consuming its later enemy action; committed, Staggered, and dead enemies do not turn.
7. Newly spawned enemies move or commit on their first funded action whenever a legal outcome exists.
