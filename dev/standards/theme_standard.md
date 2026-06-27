# Theme Standard

The project uses a single centralized theme at `global/theme/main_theme.tres`, set as the project-level theme via `project.godot` `[gui] theme/custom`. Every scene should inherit it automatically.

## Theme Scope

The base theme provides generic UI defaults first. Dash & Slash-specific visual states, custom component types, special icons, and font fallback stacks may be added here only when they are deliberate project UI direction rather than incidental one-off styling.

## What The Theme Provides

**Colors** for `Label`, `Button`, `RichTextLabel`, and tooltip text:

- Primary text: `Color(0.88, 0.88, 0.92, 1)`
- Hover text: `Color(1, 1, 1, 1)`
- Pressed text: `Color(0.75, 0.75, 0.8, 1)`
- Disabled text: `Color(0.45, 0.48, 0.53, 1)`
- Tooltip text: `Color(0.8, 0.8, 0.85, 1)`

**Font sizes** use a default of 24 for 1920x1080-friendly UI. Use `theme_type_variation` for static label sizes instead of per-node font-size overrides.

| Type Variation   | Size | Usage                     |
| ---------------- | ---: | ------------------------- |
| `DisplayLabel`   |   72 | Banner titles             |
| `TitleLabel`     |   48 | Page titles               |
| `Heading1Label`  |   42 | Major section headers     |
| `Heading2Label`  |   33 | Sub-section headers       |
| `Heading3Label`  |   30 | Minor section headers     |
| `BodyLargeLabel` |   27 | Primary body text         |
| `BodyLabel`      |   24 | Default body text         |
| `DetailLabel`    |   21 | Card content and tooltips |
| `CaptionLabel`   |   20 | Small labels              |
| `SmallLabel`     |   18 | Secondary small text      |
| `TinyLabel`      |   17 | Tiny labels               |
| `CompactLabel`   |   16 | Compact card labels       |
| `MicroLabel`     |   14 | Debug and dense UI text   |

**Container separation defaults**:

- `HBoxContainer` / `VBoxContainer`: 8
- `GridContainer`: h=6, v=6
- `HSeparator` / `VSeparator`: 8

**StyleBoxes**:

- `PanelContainer/styles/panel`: dark surface, 1px border, 4px radius
- `Button/styles/*`: all five states, `normal`, `hover`, `pressed`, `disabled`, and `focus`
- `TooltipPanel/styles/panel`: near-black surface, 1px border, 3px radius
- `HSeparator/styles/separator` and `VSeparator/styles/separator`: shared separator line

## Rules

1. Theme-level styling owns static appearance. Font sizes, default colors, panel backgrounds, button states, and container spacing belong in `main_theme.tres`.
2. Use `.tscn` `theme_type_variation` for static label size choices. Use `theme_override_font_sizes/` only when a one-off value is truly local to that scene.
3. Use GDScript `add_theme_*_override()` only for runtime state selection or computed values. If a value is applied once in `_ready()` and never changes, move it to the theme or the scene file.
4. Reusable component state StyleBoxes belong in the theme under a component-specific type only when the component has a fixed state set, such as `default`, `hovered`, `selected`, `available`, or `blocked`.
5. Do not create `StyleBoxFlat.new()` in GDScript for fixed static appearance. GDScript-built StyleBoxes are acceptable only for values that are genuinely computed at runtime, such as debug overlays or grid cells colored by a live validity check.
6. Do not hardcode repeated static UI `Color()` literals in GDScript. Add reusable static colors to the theme, and add repeated dynamic colors to a project-level semantic color constants file.
7. Do not add project-specific art direction, fonts, CJK fallback stacks, icon sets, or gameplay-specific component theme types as incidental cleanup. Add them only when Dash & Slash deliberately owns that UI direction.

## Migration Approach

Scenes are migrated incrementally. When touching a scene for other work, check whether local font-size, color, spacing, or StyleBox overrides now match theme defaults and remove redundant overrides.
