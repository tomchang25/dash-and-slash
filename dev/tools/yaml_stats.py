"""
yaml_stats.py
Print summary statistics for each registered entity type from the merged YAML data set.

This script is read-only — it never writes or modifies YAML or TRES files.

Usage:
    python yaml_stats.py --godot-root /path/to/godot/project
    python yaml_stats.py --godot-root /path/to/godot/project --yaml-dir DIR
"""

import argparse
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

from tres_lib.registry import REGISTRY


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Print YAML entity statistics for design balancing."
    )
    parser.add_argument("--godot-root", required=True)
    parser.add_argument(
        "--yaml-dir",
        default=None,
        help="Directory containing YAML files (default: <godot-root>/data/yaml)",
    )
    args = parser.parse_args()

    root = Path(args.godot_root)
    yaml_dir = Path(args.yaml_dir) if args.yaml_dir else root / "data" / "yaml"

    if not yaml_dir.is_dir():
        sys.exit(f"YAML directory not found: {yaml_dir}")

    yaml_files = sorted(yaml_dir.glob("**/*.yaml"))
    if not yaml_files:
        sys.exit(f"No .yaml files found in: {yaml_dir}")

    merged: dict[str, list] = {spec.yaml_key: [] for spec in REGISTRY}

    for yaml_path in yaml_files:
        print(f"Loading {yaml_path.name}...")
        data = yaml.safe_load(yaml_path.read_text(encoding="utf-8"))
        if not data:
            continue
        for key in merged:
            merged[key].extend(data.get(key, []) or [])

    print()
    total = 0
    for spec in REGISTRY:
        entries = merged.get(spec.yaml_key, [])
        count = len(entries)
        total += count
        print(f"  {spec.yaml_key:<30} {count:>4} entries")

    print(f"\n  {'TOTAL':<30} {total:>4} entries")


if __name__ == "__main__":
    main()
