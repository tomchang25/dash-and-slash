# Standards Enforcement

How the rules in `dev/standards/` are actually kept. Prose in a doc (or in
`CLAUDE.md`) is _advisory_ — it only works if the agent happens to attend to it
at the right moment. Anything that can be decided from the source is moved off
prose and onto a check instead.

## The model

- **One source of truth.** The rule itself lives in its standard doc
  (`scene_node_source_standard.md`, etc.). This file and the linter only
  _point back at_ it — they never restate or redefine a rule.
- **One check module.** All machine-checkable rules are decided by
  `dev/tools/lint_standards.py`. No second copy of the logic anywhere.
- **Many trigger points.** The same linter fires at more than one moment in the
  lifecycle, earliest-and-cheapest first:
  - _In-loop_ — a PostToolUse hook (`dev/tools/lint_changed.py`, wired via
    `dev/tools/lint_hook.settings.json` → `.claude/settings.json`) lints only the
    file just edited and feeds violations straight back to the agent, so drift is
    corrected as it happens instead of surviving to review.
  - _Backstop_ — the tracked pre-commit hook (`dev/tools/hooks/pre-commit`,
    installed once with `git config core.hooksPath dev/tools/hooks`) lints the
    staged `.gd`/`.tscn` at every `git commit`, and/or the same linter runs in
    CI. This is harness-agnostic: the in-loop hook only fires inside Claude Code,
    so for any other agent (opencode, a generic LLM) or a hand edit, the
    pre-commit/CI backstop is the _only_ net — it is not optional in a
    multi-agent workflow. Bypassable in an emergency with `--no-verify`.

A non-Claude-Code agent that can't run hooks should be told, in its own rules,
to run `python dev/tools/lint_standards.py --files <changed>` before finishing.

Rules a machine genuinely can't decide stay with review and human judgment —
they are not listed here. Don't pre-declare future checks; a rule earns a check
when it's actually been violated enough to be worth automating.

## Active checks

Only what `lint_standards.py` enforces today:

- **GDScript header shape and declaration placement** (`gdscript_structure_standard.md` §2-§5).
  Variable block headers must use the unpadded `# -- Group name --` shape, and function section headers must use the unpadded `# == Section name ==` shape. The check accepts custom group/section names; it only rejects padded or malformed header syntax.

  The same check also enforces the standard declaration block flow where it is syntactic: recognized variable blocks appear in declaration order (`Constants`, `Exports`, `State`, `Timer / tween handles`, `Node references`), and top-level declarations such as `const`, `var`, `@export var`, `@onready var`, `signal`, and `enum` must not appear after function sections have begun.

- **Node-source rule** (`scene_node_source_standard.md` §5). A machine
  can't tell whether a node is persistent, so the convention makes intent
  syntactic: every runtime `add_child` that is _not_ a `.instantiate()`'d packed
  scene must carry a `# node-src: <tag>` marker (on the line directly above the
  call, preferred, or trailing it) naming the permitted exception.
  Unmarked → violation. Tags map 1:1 to the standard's exceptions table:
  `instance`, `ephemeral`, `drawn`, `debug`, `timer`.

  ```gdscript
  # node-src: timer
  add_child(_npc_timer)

  # node-src: ephemeral — separator in rebuilt list
  _lot_summary.add_child(HSeparator.new())

  # node-src: debug
  add_child(_debug_label)
  ```

  A _wrong_ claim (e.g. `# node-src: ephemeral` on a clearly persistent node) is
  now greppable — that's exactly what a reviewer checks by eye.

- **No signal connections in `.tscn`** (`gdscript_structure_standard.md`, Signal connections).
  Any `[connection]` block in a scene file fails; connect signals in `_ready()`
  so the full wiring surface is visible in code.

- **Feature scene assets are feature-owned** (`asset_ownership_standard.md` §2). A scene under `game/` cannot reference `res://assets/`; its resource must live with the owning feature or be an intentional shared asset.

- **No fragile direct node lookup** (`scene_node_source_standard.md`, Node Reference Style).
  Direct `get_node(...)`, `get_node_or_null(...)`, and `find_child(...)` calls fail unless the immediately preceding line carries `# node-ref: allow - <reason>`. Fixed scene nodes should be referenced with `%UniqueName` `@onready` variables, and cross-boundary access should go through a narrow API or signal.

- **No bare `push_error()` / `push_warning()` at call sites** (`error_guard_standard.md` §3).
  Runtime guards use `ToastManager.show_error()`, programmer errors use `ToastManager.show_dev_error()`, and recovery warnings use `ToastManager.show_warning()`. Exceptions are `toast_manager.gd` itself and boot-phase code that runs before ToastManager loads, marked with `# push-error: boot`.

## Adding a check

Each check is a function `(rel_path, text) -> [Violation]` registered in
`GD_CHECKS` or `TSCN_CHECKS` in `lint_standards.py`. Every `Violation` cites the
standard section it enforces, so the linter never becomes a second source of
truth. Add a check only when a rule is both machine-decidable and worth the
maintenance — then document it under _Active checks_ above.
