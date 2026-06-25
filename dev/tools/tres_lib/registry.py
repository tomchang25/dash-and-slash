"""Entity registry — processing order matters (dependency order)."""

from tres_lib.entities.example_entity import SPEC as example_entity_spec

REGISTRY = [
    example_entity_spec,
]
