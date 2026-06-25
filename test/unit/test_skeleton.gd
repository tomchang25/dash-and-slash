# test_skeleton.gd
# Minimal unit test to verify the GUT test runner pipeline is wired correctly.
extends GutTest


func test_pipeline_is_alive() -> void:
	assert_true(true, "The test runner pipeline should be alive")
