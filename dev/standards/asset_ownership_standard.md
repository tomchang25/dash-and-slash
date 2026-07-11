# Feature Asset Ownership

This standard keeps shipped feature scenes independent from the ignored root `assets/` vendor/reference directory.

## 1. Asset placement and ownership

Source art, audio, and other imported files used by exactly one game feature belong under that feature's `assets/` folder. If a feature contains several independently owned components or entities, group assets by consumer beneath that folder.

```
game/
  entities/
    enemies/
      assets/
        small_enemy/
        charge_enemy/
```

`assets/` at the repository root is an ignored vendor/reference directory. It may be used as a local source when preparing an asset, but no shipped scene or resource may depend on a `res://assets/` path.

When an asset is genuinely used by a second feature, move it to `game/shared/assets/` at that time. Do not promote a single-feature asset to shared pre-emptively.

## 2. Scene resource paths

Every `.tscn` under `game/` must reference source assets from its owning feature or from `game/shared/assets/`. An external resource path beginning with `res://assets/` is prohibited.

Copy or move only the source asset into its owned destination. Do not copy a `.import` sidecar: it contains the previous source path and imported-resource UID. Godot regenerates it for the new location.

## 3. Enforcement

`dev/tools/lint_standards.py` rejects `res://assets/` resource paths in scenes under `game/`. Run the standards linter on every changed `.tscn` before handing off work.
