# Error Guard Standard

`assert()` is stripped in release exports, turning guards into silent crashes or invalid state. Every precondition check must use an explicit `if` guard that survives in all build configurations.

---

# 1. Why Not `assert()`

In a Godot release export, `assert(condition, message)` compiles to nothing. The following code:

```gdscript
assert(current_state != null, "current_state is null")
current_state.enter()
```

becomes a bare null-dereference with no context. The player sees a frozen screen or a sudden exit, and the log may not identify the real guard that failed.

The replacement is an explicit `if` guard:

```gdscript
if current_state == null:
	ToastManager.show_dev_error("StateMachine: current_state is null before enter()")
	return
```

---

# 2. Guard Categories

| Category         | Who sees it | Toast channel                   | Fallback                                                     |
| ---------------- | ----------- | ------------------------------- | ------------------------------------------------------------ |
| Runtime guard    | Player      | `ToastManager.show_error()`     | Navigate to a safe scene or show a recoverable failure state |
| Programmer error | Developer   | `ToastManager.show_dev_error()` | `return` / safe sentinel                                     |
| Recovery warning | Player      | `ToastManager.show_warning()`   | Continue with the recovered state                            |
| Diagnostic info  | Developer   | `ToastManager.show_info()`      | Continue normally                                            |

## Runtime Guard

A condition that can fail due to scene-flow bugs, state desync, corrupt input, or edge-case navigation. The player might encounter this and needs a visible recovery path.

```gdscript
if required_payload == null:
	ToastManager.show_error("Scene failed to load required data. Returning to start.")
	SceneRouter.go_to_start.call_deferred()
	return
```

Use `show_error()` for player-facing runtime failure messages. It writes to the error log internally, so do not add a separate `push_error()` at the call site. Include context in the message because the log location points at ToastManager, not the guard.

## Programmer Error

A condition that signals a bug in the codebase itself, including violated preconditions, invalid arguments, broken invariants, or impossible match branches.

```gdscript
func spend(amount: int) -> bool:
	if amount < 0:
		ToastManager.show_dev_error("spend() expects non-negative amount, got %d" % amount)
		return false
```

Use `show_dev_error()` for programmer errors. It always writes `push_error("[DEV] " + message)` internally, shows the toast only when `Debug.enabled`, and dedupes repeated toasts per session so guards in per-frame or loop paths do not spam the screen.

## Recovery Warning

Use `show_warning()` when the operation recovered but the player should know about degradation, dropped data, fallback behavior, or a skipped optional resource.

```gdscript
ToastManager.show_warning("Loaded fallback settings because the saved settings file was corrupt.")
```

Warnings are always visible. They should be actionable or explanatory, not routine success feedback.

## Diagnostic Info

Use `show_info()` for debug-only diagnostics such as migration notes, internal routing details, or development-only observations. Never use it for error guards.

```gdscript
ToastManager.show_info("Applied migration v2 to player profile data.")
```

---

# 3. No Bare `push_error` / `push_warning`

All error logging flows through `ToastManager.show_error()` or `ToastManager.show_dev_error()`. A bare `push_error()` at a call site is a violation because it skips the toast channel or duplicates ToastManager's logging.

Warnings use `ToastManager.show_warning()` unless they are debug-only diagnostic details, which use `ToastManager.show_info()`.

Allowed exceptions:

- `global/autoloads/toast_manager.gd` is the single home of the underlying `push_error()` calls.
- Boot-phase code that can run before ToastManager loads may use bare `push_error()` / `push_warning()` with a `# push-error: boot` marker on the same line or the comment line directly above.

```gdscript
push_error("SettingsStore: settings file corrupt, using defaults") # push-error: boot
```

The boot marker is only legitimate in code that can run before ToastManager exists.

---

# 4. Summary

| Need                                                    | Use                                                           |
| ------------------------------------------------------- | ------------------------------------------------------------- |
| Scene or runtime flow cannot continue safely            | `ToastManager.show_error(msg)` + safe fallback                |
| Internal invariant or precondition broke                | `ToastManager.show_dev_error(msg)` + `return` / safe sentinel |
| Recovered with degradation the player should know about | `ToastManager.show_warning(msg)`                              |
| Debug-only diagnostic detail                            | `ToastManager.show_info(msg)`                                 |
| Error before ToastManager loads                         | bare `push_error()` / `push_warning()` + `# push-error: boot` |
