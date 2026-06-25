# Save Migrations

Save files live on player disks. Code that parses old save formats is not dead code, even when nothing in the current codebase writes that format anymore. That is exactly what a migration is.

## Never Delete Without Sign-Off

- Versioned migration blocks such as `if from_version < N:` are append-only. Old blocks stay in place so saves can migrate through every historical step.
- Legacy-key reads in `from_dict()` or migrations are intentional compatibility paths. The old keys no longer existing in authored data or current saves is not proof they are removable.
- Always-run idempotent migrations are compatibility code, not cleanup targets.
- Defensive `has()`, `get(..., default)`, and fallback reads in load paths usually exist for saves written before a field existed.

Deleting or simplifying any compatibility path requires explicit user sign-off and is normally only done at a declared save-compatibility break.

## When Refactoring Serialized Data

If you rename, remove, restructure, or reinterpret any field that appears in `to_dict()` or `from_dict()`:

1. Bump the relevant store/provider version.
2. Append a new migration step that rewrites the old payload into the new shape. Migrate the data rather than branching normal runtime code around old formats.
3. Leave older migration steps untouched so saves can chain through `v1 -> v2 -> v3`.
4. Log or surface degraded/dropped data through the project's load context or warning mechanism. Dropping data must not be silent.
5. If a migration depends on a type or lookup being refactored away, stop and ask before removing it. Options include keeping a minimal legacy lookup, snapshotting required data into the migration, or accepting a declared data loss with sign-off.
6. Stamp the migrated payload with the current version after all migration steps so re-entering the load path does not re-apply earlier migrations.

Use the project's save architecture for the exact location: whole-file migrations belong in the save coordinator when it owns the whole payload view; per-section migrations belong in the provider/store that owns that section.
