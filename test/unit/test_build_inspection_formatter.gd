# test_build_inspection_formatter.gd
# Tests BuildInspectionFormatter's channel filtering/ordering, flat/percent value formatting,
# mobility payload/trigger summaries, and owned-artifact row assembly, all without instancing the
# build inspection panel scene.
extends GutTest

func test_channel_rows_skip_zero_channels_and_keep_stable_order() -> void:
    var run_build := RunBuild.new()
    run_build.record(RunBuild.CH_MAX_HEALTH, 20.0)
    run_build.record(RunBuild.CH_NORMAL_ATTACK_DAMAGE, 10.0)

    var rows := BuildInspectionFormatter.build_channel_rows(run_build)

    assert_eq(rows.size(), 2, "only the two non-zero channels should produce rows")
    assert_eq(rows[0]["label"], "Normal Attack Damage", "Normal Attack Damage precedes Max Health in the stable channel order")
    assert_eq(rows[1]["label"], "Max Health")


func test_flat_channel_formats_with_explicit_sign() -> void:
    var run_build := RunBuild.new()
    run_build.record(RunBuild.CH_NORMAL_ATTACK_DAMAGE, 10.0)
    run_build.record(RunBuild.CH_MOBILITY_COOLDOWN, -1.0)

    assert_eq(BuildInspectionFormatter.format_channel_value(RunBuild.CH_NORMAL_ATTACK_DAMAGE, run_build.total(RunBuild.CH_NORMAL_ATTACK_DAMAGE)), "+10")
    assert_eq(BuildInspectionFormatter.format_channel_value(RunBuild.CH_MOBILITY_COOLDOWN, run_build.total(RunBuild.CH_MOBILITY_COOLDOWN)), "-1")


func test_mobility_range_channel_displays_flat_cell_bonus() -> void:
    var run_build := RunBuild.new()
    run_build.record(RunBuild.CH_MOBILITY_RANGE, 1.0)

    assert_eq(BuildInspectionFormatter.format_channel_value(RunBuild.CH_MOBILITY_RANGE, run_build.total(RunBuild.CH_MOBILITY_RANGE)), "+1")


func test_percent_fraction_channel_scales_stored_fraction_by_100() -> void:
    var run_build := RunBuild.new()
    run_build.record(RunBuild.CH_ENEMY_HEALTH_PRESSURE, 0.05)

    assert_eq(BuildInspectionFormatter.format_channel_value(RunBuild.CH_ENEMY_HEALTH_PRESSURE, run_build.total(RunBuild.CH_ENEMY_HEALTH_PRESSURE)), "+5%")


func test_unknown_channel_reports_unknown_instead_of_crashing() -> void:
    assert_eq(BuildInspectionFormatter.format_channel_value(&"not_a_real_channel", 5.0), "Unknown")
    assert_push_error("unknown channel 'not_a_real_channel'")


func test_payload_row_reports_active_payload_label() -> void:
    var run_build := RunBuild.new()

    assert_eq(BuildInspectionFormatter.build_payload_row(run_build)["value"], "Dash", "Dash is the default mobility payload")

    run_build.set_mobility_payload_override(RunBuild.PAYLOAD_SMASH)
    assert_eq(BuildInspectionFormatter.build_payload_row(run_build)["value"], "Smash")


func test_trigger_rows_report_none_when_no_trigger_is_active() -> void:
    var run_build := RunBuild.new()

    var rows := BuildInspectionFormatter.build_trigger_rows(run_build)

    assert_eq(rows.size(), 1)
    assert_eq(rows[0]["label"], "Mobility Triggers")
    assert_eq(rows[0]["value"], "None")


func test_trigger_rows_list_each_active_trigger_in_stable_order() -> void:
    var run_build := RunBuild.new()
    run_build.set_mobility_trigger(RunBuild.TRIGGER_EXECUTION, true)
    run_build.set_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER, true)

    var rows := BuildInspectionFormatter.build_trigger_rows(run_build)

    assert_eq(rows.size(), 2)
    assert_eq(rows[0]["label"], "Guard Shredder", "Guard Shredder precedes Execution in the stable trigger order")
    assert_eq(rows[1]["label"], "Execution")


func test_artifact_rows_include_stack_scaled_description() -> void:
    var run_build := RunBuild.new()
    var artifact := _make_speed_artifact()
    run_build.acquire_artifact(artifact, 2)

    var rows := BuildInspectionFormatter.build_artifact_rows(run_build)

    assert_eq(rows.size(), 1)
    assert_eq(rows[0]["artifact"], artifact)
    assert_eq(rows[0]["stacks"], 2)
    assert_eq(rows[0]["description"], "+2 Speed")


func _make_speed_artifact() -> Artifact:
    var effect := ChannelArtifactEffect.new()
    effect.channel = RunBuild.CH_SPEED
    effect.amount = 1.0

    var artifact := Artifact.new()
    artifact.id = &"speed_up"
    artifact.display_name = "Fleet Step"
    artifact.description_template = "+%d Speed"
    artifact.max_stacks = 5
    artifact.magnitude = 1.0
    artifact.effects = [effect]
    return artifact
