# build_inspection_formatter.gd
# Stateless formatting/data-assembly for the build inspection panel: stable channel display order
# and labels, flat/percent value formatting, class/Mobility and trigger labels, and owned-artifact
# row assembly from RunBuild's read API. Kept free of any Control/scene reference so it can be
# unit-tested without instancing the panel.
class_name BuildInspectionFormatter
extends RefCounted

## How a channel's raw RunBuild.total() value maps to display text.
enum ChannelUnit {
    FLAT,
    PERCENT_FRACTION,
}

const ROW_STYLE_CHANNEL := &"DetailLabel"
const ROW_STYLE_SUMMARY := &"CaptionLabel"

const _CHANNEL_ORDER: Array[StringName] = [
    RunBuild.CH_NORMAL_ATTACK_DAMAGE,
    RunBuild.CH_NORMAL_ATTACK_COOLDOWN,
    RunBuild.CH_MOBILITY_ATTACK_DAMAGE,
    RunBuild.CH_DASH_COOLDOWN,
    RunBuild.CH_MOBILITY_RANGE,
    RunBuild.CH_MAX_HEALTH,
    RunBuild.CH_SPEED,
    RunBuild.CH_MOBILITY_COOLDOWN,
    RunBuild.CH_FUTURE_ENEMY_COUNT,
    RunBuild.CH_ENEMY_HEALTH_PRESSURE,
    RunBuild.CH_ENEMY_DAMAGE_PRESSURE,
    RunBuild.CH_ENEMY_DEFENSE_PRESSURE,
]

const _CHANNEL_LABELS := {
    RunBuild.CH_NORMAL_ATTACK_DAMAGE: "Normal Attack Damage",
    RunBuild.CH_NORMAL_ATTACK_COOLDOWN: "Normal Attack Cooldown",
    RunBuild.CH_MOBILITY_ATTACK_DAMAGE: "Mobility Damage",
    RunBuild.CH_DASH_COOLDOWN: "Dash Cooldown",
    RunBuild.CH_MOBILITY_RANGE: "Mobility Range",
    RunBuild.CH_MAX_HEALTH: "Max Health",
    RunBuild.CH_SPEED: "Speed Energy",
    RunBuild.CH_MOBILITY_COOLDOWN: "Mobility Cooldown",
    RunBuild.CH_FUTURE_ENEMY_COUNT: "Future Enemies",
    RunBuild.CH_ENEMY_HEALTH_PRESSURE: "Enemy Health",
    RunBuild.CH_ENEMY_DAMAGE_PRESSURE: "Enemy Damage",
    RunBuild.CH_ENEMY_DEFENSE_PRESSURE: "Enemy Defense",
}

# enemy_health/damage_pressure are authored as 0-1 fractions (unit_scale 0.01) and need *100.
const _CHANNEL_UNITS := {
    RunBuild.CH_NORMAL_ATTACK_DAMAGE: ChannelUnit.FLAT,
    RunBuild.CH_NORMAL_ATTACK_COOLDOWN: ChannelUnit.FLAT,
    RunBuild.CH_MOBILITY_ATTACK_DAMAGE: ChannelUnit.FLAT,
    RunBuild.CH_DASH_COOLDOWN: ChannelUnit.FLAT,
    RunBuild.CH_MOBILITY_RANGE: ChannelUnit.FLAT,
    RunBuild.CH_MAX_HEALTH: ChannelUnit.FLAT,
    RunBuild.CH_SPEED: ChannelUnit.FLAT,
    RunBuild.CH_MOBILITY_COOLDOWN: ChannelUnit.FLAT,
    RunBuild.CH_FUTURE_ENEMY_COUNT: ChannelUnit.FLAT,
    RunBuild.CH_ENEMY_HEALTH_PRESSURE: ChannelUnit.PERCENT_FRACTION,
    RunBuild.CH_ENEMY_DAMAGE_PRESSURE: ChannelUnit.PERCENT_FRACTION,
    RunBuild.CH_ENEMY_DEFENSE_PRESSURE: ChannelUnit.FLAT,
}

const _TRIGGER_ORDER: Array[StringName] = [
    RunBuild.TRIGGER_GUARD_SHREDDER,
    RunBuild.TRIGGER_EXECUTION,
    RunBuild.TRIGGER_CHAIN_DASH,
]

const _TRIGGER_LABELS := {
    RunBuild.TRIGGER_GUARD_SHREDDER: "Guard Shredder",
    RunBuild.TRIGGER_EXECUTION: "Execution",
    RunBuild.TRIGGER_CHAIN_DASH: "Chain Dash",
}

# == Common API ==


## Returns one `{ "label": String, "value": String, "style": StringName }` row per non-zero
## RunBuild channel, in the fixed display order every reopen of the panel should reproduce.
static func build_channel_rows(run_build: RunBuild) -> Array[Dictionary]:
    var rows: Array[Dictionary] = []
    for channel in _CHANNEL_ORDER:
        var total := run_build.total(channel)
        if is_zero_approx(total):
            continue
        rows.append({ "label": _CHANNEL_LABELS[channel], "value": format_channel_value(channel, total), "style": ROW_STYLE_CHANNEL })
    return rows


## Returns always-present class and fixed-Mobility summary rows.
static func build_class_rows(character_class: CharacterClassData) -> Array[Dictionary]:
    if character_class == null:
        ToastManager.show_dev_error("BuildInspectionFormatter: missing CharacterClassData")
        return [
            { "label": "Class", "value": "Unknown", "style": ROW_STYLE_SUMMARY },
            { "label": "Mobility", "value": "Unknown", "style": ROW_STYLE_SUMMARY },
        ]
    return [
        { "label": "Class", "value": character_class.display_name, "style": ROW_STYLE_SUMMARY },
        { "label": "Mobility", "value": character_class.mobility_display_name(), "style": ROW_STYLE_SUMMARY },
    ]


## Returns one row per active mobility trigger, or a single explicit "None" row when no trigger is
## active. Never returns an empty array, so the totals list always shows a trigger summary.
static func build_trigger_rows(run_build: RunBuild) -> Array[Dictionary]:
    var rows: Array[Dictionary] = []
    for trigger_id in _TRIGGER_ORDER:
        if run_build.has_mobility_trigger(trigger_id):
            rows.append({ "label": _TRIGGER_LABELS[trigger_id], "value": "", "style": ROW_STYLE_SUMMARY })
    if rows.is_empty():
        rows.append({ "label": "Mobility Triggers", "value": "None", "style": ROW_STYLE_SUMMARY })
    return rows


## Returns one `{ "artifact": Artifact, "stacks": int, "description": String }` row per owned
## artifact entry. A malformed entry (missing artifact or non-positive stacks) is skipped and
## reported instead of rendering fake data or crashing the panel.
static func build_artifact_rows(run_build: RunBuild) -> Array[Dictionary]:
    var rows: Array[Dictionary] = []
    for entry in run_build.get_owned_artifacts():
        var picked_artifact: Artifact = entry.get("artifact")
        var stacks: int = entry.get("stacks", 0)
        if picked_artifact == null or stacks <= 0:
            ToastManager.show_dev_error("BuildInspectionFormatter: malformed owned-artifact entry, skipping row")
            continue
        rows.append({ "artifact": picked_artifact, "stacks": stacks, "description": picked_artifact.format_description(stacks) })
    return rows


## Formats one channel's raw total per its authored unit: signed flat number or a stored fraction
## scaled to percentage points.
static func format_channel_value(channel: StringName, total: float) -> String:
    if not _CHANNEL_UNITS.has(channel):
        ToastManager.show_dev_error("BuildInspectionFormatter: unknown channel '%s'" % channel)
        return "Unknown"
    match _CHANNEL_UNITS[channel]:
        ChannelUnit.FLAT:
            return _format_signed_number(total)
        ChannelUnit.PERCENT_FRACTION:
            return "%s%%" % _format_signed_number(total * 100.0)
        _:
            ToastManager.show_dev_error("BuildInspectionFormatter: unhandled channel unit for '%s'" % channel)
            return "Unknown"

# == Value Formatting ==


static func _format_signed_number(value: float) -> String:
    var text: String
    if is_equal_approx(value, roundf(value)):
        text = str(int(roundf(value)))
    else:
        text = str(value)
    if value >= 0.0:
        text = "+" + text
    return text
