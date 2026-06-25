# State Machine Usage Pattern

## Traps / Common Wrong Code

The `StateMachine` + `State` framework in `common/framework/state_machine/` is a **behaviour-delegation** system, not a state-label holder. The single most common anti-pattern is treating states as hollow integer labels and writing all state logic in the entity's `_physics_process` with a `match` on `current_state.state_id`.

### Wrong (do not use)

```gdscript
# player.gd — EVERYTHING BELOW IS THE ANTI-PATTERN
func _physics_process(_delta: float) -> void:
    match _state_machine.current_state.state_id:       # entity dispatches — WRONG
        StateId.IDLE:    _physics_idle()
        StateId.MOVE:    _physics_move()
        StateId.ATTACK:  _physics_attack()
    move_and_slide()

func _try_attack() -> void:
    _state_machine.request_transition(StateId.ATTACK)  # external push — WRONG for normal transitions
```

States in the `.tscn` use the raw `State` base class with no custom script — just `state_id = 0/1/2`. Zero behaviour in states; all logic crammed into the entity.

### Why it is wrong

- The `StateMachine`'s own `_process` / `_physics_process` are designed to call `current_state.update()` / `current_state.physics_update()`. The entity's `_physics_process` bypasses them entirely.
- `State._enter()` / `_exit()` hooks are never used. Every state's setup and teardown (animation, movement stop, signal connect/disconnect) is scattered across the entity.
- Transitions are pushed externally via `request_transition()` instead of pulled internally by the state via `change_state()`. The entity must know every state's transition rules.
- Adding a new state means touching the entity's `match`, `_try_*` methods, and `.tscn` — instead of one new state script.

---

## Correct Pattern

### Architecture

```
StateMachine._process(delta)          StateMachine._physics_process(delta)
  → current_state.update(delta)         → current_state.physics_update(delta)
       │                                      │
       ▼                                      ▼
  player_move_state._update()          player_move_state._physics_update()
       │ reads                              │ reads
       ▼                                     ▼
  player.get_move_input()               player.set_movement_velocity()
  player.consume_attack_request()
```

The entity provides a **public query API**. States **read** the entity to decide transitions and **call** the entity to drive movement/animation/combat. The entity's own `_process` / `_physics_process` contains **zero** state-dispatch logic — that is the `StateMachine`'s job.

### Entity shape

```gdscript
# player.gd
extends CharacterBody2D

@export var state_machine: StateMachine
@export var movement_module: MovementModule
@export var animation_module: AnimationModule
@export var combat_module: CombatModule

# -- Public API (called BY states, not the other way around) --

func get_move_input() -> Vector2:
    return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func consume_attack_request() -> bool:
    return can_attack() and Input.is_action_pressed("attack")

func consume_dodge_request() -> bool:
    # consume-once pattern: flag set in _unhandled_input, consumed here
    var req := _dodge_requested
    _dodge_requested = false
    return req

func set_movement_velocity(direction: Vector2, speed: float) -> void:
    movement_module.set_manual_velocity(direction.normalized() * speed)

func stop_movement() -> void:
    movement_module.stop_manual_motion()

func play_animation(state_name: StringName, time_scale: float = 1.0) -> void:
    animation_module.travel(state_name)
    animation_module.set_time_scale(time_scale)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("dodge"):
        _dodge_requested = true
```

### State base class (optional: typed entity reference)

A per-entity intermediate class gives each state a typed handle to its owner without repeated casts:

```gdscript
# player_state.gd
class_name PlayerState
extends State

enum PlayerStateId {
    NULL = -1,
    IDLE = 0,
    MOVE = 1,
    ROLL = 2,
    ATTACK = 3,
}

var player: Player

func _ready() -> void:
    await owner.ready
    player = owner as Player
```

### Concrete state

Each state extends the intermediate class (or `State` directly), sets `state_id` in `_init()`, and implements the hooks it needs:

```gdscript
# player_idle_state.gd
extends PlayerState

func _init() -> void:
    state_id = PlayerStateId.IDLE

func _enter() -> void:
    player.stop_movement()
    player.play_animation(Player.ANIM_IDLE)

func _update(_delta: float) -> void:
    if player.consume_attack_request():
        change_state(PlayerStateId.ATTACK)       # internal transition
        return
    if player.consume_dodge_request():
        change_state(PlayerStateId.ROLL)         # internal transition
        return
    if player.get_move_input() != Vector2.ZERO:
        change_state(PlayerStateId.MOVE)
```

```gdscript
# player_attack_state.gd
extends PlayerState

func _init() -> void:
    state_id = PlayerStateId.ATTACK

func _enter() -> void:
    var target_pos := player.get_attack_target_position()
    player.play_animation(Player.ANIM_ATTACK)
    player.perform_attack(target_pos)
    if not player.attack_finished.is_connected(_on_attack_finished):
        player.attack_finished.connect(_on_attack_finished)

func _physics_update(_delta: float) -> void:
    # allow slight drift while attacking
    var input_dir := player.get_move_input()
    if input_dir != Vector2.ZERO:
        player.set_movement_velocity(input_dir, 100.0)

func _exit() -> void:
    if player.attack_finished.is_connected(_on_attack_finished):
        player.attack_finished.disconnect(_on_attack_finished)
    player.stop_movement()

func _on_attack_finished() -> void:
    player.end_attack()
    change_state(PlayerStateId.IDLE)              # internal transition
```

### Scene wiring (.tscn)

```
StateMachine (Node, script=state_machine.gd, tick_enabled=false, initial_state=NodePath("Idle"))
├── Idle    (Node, script=player_idle_state.gd)      ← custom script, NOT raw State
├── Move    (Node, script=player_move_state.gd)
├── Attack  (Node, script=player_attack_state.gd)
└── Roll    (Node, script=player_roll_state.gd)
```

- Use `tick_enabled = false` for real-time entity FSMs — the StateMachine's `_process` / `_physics_process` will call the current state every frame.
- Use `tick_enabled = true` only when you want throttled updates (e.g. AI decision polling at 2 Hz).

---

## Transition Paths

| Path | Who calls it | When to use |
|---|---|---|
| `change_state(to)` | The state itself, in `_update` / `_physics_update` / signal callback | Normal state-driven transitions (idle → move, attack → idle) |
| `request_transition(to)` | The entity or an external system (driver, Beehave) | Interrupts from outside (damage → stagger, death, cutscene takeover) |
| `request_transition(to, true)` | Same, with `force = true` | Must-fire transitions that ignore `interruptible` flag |

**Rule of thumb**: if the decision lives inside the current state, use `change_state()`. If the decision comes from outside the state machine, use `request_transition()`.

---

## Rules Summary

1. Every state MUST have its own script extending `State` (or a per-entity intermediate like `PlayerState`). Never use raw `State` in a `.tscn` for a concrete state.
2. State behaviour lives in `_enter()`, `_update()`, `_physics_update()`, `_exit()`. The entity's `_physics_process` MUST NOT contain a `match` on `current_state.state_id` to dispatch state logic.
3. States transition internally with `change_state()`. External interrupts use `request_transition()`.
4. The entity exposes a public query/command API for states to call: `get_move_input()`, `consume_attack_request()`, `set_movement_velocity()`, `play_animation()`, etc.
5. Set `tick_enabled = false` on the StateMachine for real-time entities.
6. Connect animation-finished / attack-finished signals in `_enter()`, disconnect in `_exit()`.
7. Set `state_id` in `_init()`, not in `_ready()`, so the StateMachine can register states before entering the initial state.
8. The enum of state IDs lives in the state base class (e.g. `PlayerState.PlayerStateId`), not in the entity, to avoid circular dependency.
