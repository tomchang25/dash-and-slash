# Runtime Ownership

This document defines which runtime role may own which state. Naming conventions define the suffix; this standard defines the ownership boundary behind the suffix.

---

# 1. Primary Test

Classify runtime code by lifetime, source of truth, and save/checkpoint requirement before choosing a suffix.

| Question                                                                                     | If yes                                                               | If no                           |
| -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------------------- |
| Does the state exist only inside one active scene/session and get discarded with that scene? | It may belong to a `Controller`.                                     | It needs a domain owner.        |
| Must the state survive save/load, checkpoint restore, scene changes, or run resume?          | It belongs to a `Store`, save provider, `System`, or explicit owner. | It may remain scene-local.      |
| Is the state trusted by multiple systems as domain truth?                                    | It belongs to the concept owner.                                     | A controller may coordinate it. |
| Is the script pure computation with no mutable state or side effects?                        | It may be a `Service` or helper.                                     | Do not call it a pure service.  |

---

# 2. Controller

Use `Controller` for scene-scoped scripts that orchestrate runtime flow between scene nodes, UI, and domain owners for the current active session.

A controller may own state that is discarded with the scene, such as current wave index, pending spawns, current reward offer, selected interaction mode, pending transition, or run-local pressure modifiers, when the game does not support checkpoint/save restoration for that session.

A controller may call owners to apply durable effects, but it must not silently become a second source of truth for another domain.

Examples:

| Good controller state                                 | Reason                                        |
| ----------------------------------------------------- | --------------------------------------------- |
| Current reward offer                                  | UI flow state for the current choice.         |
| Pending spawn cells                                   | Transition state between telegraph and spawn. |
| Current wave index in a no-checkpoint five-wave scene | Scene-local run flow state.                   |
| Active targeting mode                                 | Input/UI flow state.                          |

---

# 3. Domain Owners

State that must outlive the controller, be serialized, be restored from checkpoint, or serve as cross-system truth belongs to the owner of that concept.

Examples:

| Concept                                                         | Owner                                              |
| --------------------------------------------------------------- | -------------------------------------------------- |
| Persisted settings                                              | Settings store/provider.                           |
| Player stat modifiers                                           | Player-stat owner.                                 |
| Wave/run progression that must survive outside the active scene | Wave/run owner.                                    |
| Terrain truth                                                   | Terrain authority such as `GridArena`.             |
| Save payload                                                    | The provider that owns the state being serialized. |

If a scene-local controller state later needs checkpoint, save, or cross-scene resume, promote that state into the relevant owner instead of adding ad-hoc persistence to the controller.

---

# 4. System

Use `System` for a domain coordinator, mutation gateway, save provider, or aggregate owner when a concept is broader than one scene or must mediate mutations for consistency.

A system may own state directly or hold stores depending on the project architecture. It should expose narrow mutation methods so scene code does not bypass invariants.

---

# 5. Store

Use `Store` for a mutable domain state container when the project architecture uses stores. Stores own live fields for one domain and guard their invariants through mutators.

A store is appropriate when state needs serialization, validation, migration, or coordinated access by a system. Do not create a store only to hold short-lived UI flow state that dies with the scene.

---

# 6. Service

Use `Service` only for stateless computation. A service takes inputs, computes outputs, and returns results without owning mutable state, mutating stores, changing scene nodes, opening UI, or applying gameplay side effects.

Examples:

| Good service/helper work                          | Not service work         |
| ------------------------------------------------- | ------------------------ |
| Roll three reward cards from an input pool.       | Show the reward overlay. |
| Compute valid terrain candidates from inputs.     | Mutate terrain truth.    |
| Compute spawn count from wave data and modifiers. | Start the next wave.     |

Code that applies side effects may still be a helper or applier, but do not classify it as a pure service.
