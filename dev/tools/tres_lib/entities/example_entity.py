"""EntitySpec for example entities.

Template starter — copy this file and adapt it for your own entity type.
Steps:
  1. Create data/definitions/<x>_data.gd with your fields.
  2. Add data/yaml/<x>.yaml with your entries.
  3. Copy this spec, change yaml_key / tres_subdir / uid_prefix / script_paths.
  4. Register the SPEC in tres_lib/registry.py.
  5. Create global/autoloads/registries/<x>_registry.gd extends ResourceRegistry.
  6. Add to project.godot autoloads + DataPaths constant.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter
from tres_lib.tres_format import header_uid, field as tres_field


@dataclass
class ExampleEntitySpec:
    yaml_key: str = "example_entities"
    tres_subdir: str = "examples"
    uid_prefix: str = "example"
    script_paths: dict[str, str] = field(default_factory=lambda: {
        "example_entity_data": "res://data/definitions/example_entity_data.gd",
    })

    def entity_id(self, entry: dict) -> str:
        return entry["entity_id"]

    def build_label(self, entry: dict) -> str:
        return f"example ({entry.get('display_name', '?')})"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        eid = entry["entity_id"]
        uid = deterministic_uid(self.uid_prefix, eid)
        ctx.uid_cache[eid] = uid

        w = TresWriter("Resource", "ExampleEntityData", uid)
        w.add_ext_resource(
            "1_script",
            "Script",
            "res://data/definitions/example_entity_data.gd",
            ctx.script_uids["example_entity_data"],
        )
        w.add_field('script = ExtResource("1_script")')
        w.add_field_str("entity_id", eid)
        w.add_field_str("display_name", entry.get("display_name", ""))
        w.add_field_int("value", int(entry.get("value", 0)))
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict:
        uid = header_uid(text)
        eid = tres_field(text, "entity_id") or ""
        if uid:
            ctx.uid_to_id[uid] = eid
        return {
            "entity_id": eid,
            "display_name": tres_field(text, "display_name") or "",
            "value": int(tres_field(text, "value") or 0),
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        seen_ids: set[str] = set()
        for e in entries:
            eid = e.get("entity_id", "?")
            if eid in seen_ids:
                errors.append(f"example_entity: duplicate entity_id '{eid}'")
            seen_ids.add(eid)
            if not isinstance(e.get("display_name"), str) or not e["display_name"].strip():
                errors.append(f"example_entity '{eid}': display_name is required")
            val = e.get("value")
            if not isinstance(val, int):
                errors.append(f"example_entity '{eid}': value must be an int, got {type(val).__name__}")
        return errors


SPEC = ExampleEntitySpec()
