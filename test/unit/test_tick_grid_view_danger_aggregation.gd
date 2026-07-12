# test_tick_grid_view_danger_aggregation.gd
# Tests the deterministic per-cell countdown aggregation used by TickGridView's danger overlay.
extends GutTest

func test_three_sources_at_same_ticks_collapse_to_one_entry_with_count() -> void:
    var cell := Vector2i(2, 2)
    var danger: Array[Dictionary] = [
        { "cells": [cell], "ticks": 2 },
        { "cells": [cell], "ticks": 2 },
        { "cells": [cell], "ticks": 2 },
    ]

    var summaries := TickGridView.aggregate_cell_summaries(danger)

    var entries: Array[Dictionary] = summaries[cell]
    assert_eq(entries.size(), 1, "equal countdowns should collapse into one entry")
    assert_eq(int(entries[0]["ticks"]), 2)
    assert_eq(int(entries[0]["count"]), 3)


func test_distinct_timers_sort_ascending_regardless_of_arrival_order() -> void:
    var cell := Vector2i(5, 5)
    var danger: Array[Dictionary] = [
        { "cells": [cell], "ticks": 3 },
        { "cells": [cell], "ticks": 1 },
        { "cells": [cell], "ticks": 2 },
    ]

    var entries: Array[Dictionary] = TickGridView.aggregate_cell_summaries(danger)[cell]

    assert_eq(entries.size(), 3)
    assert_eq(int(entries[0]["ticks"]), 1)
    assert_eq(int(entries[1]["ticks"]), 2)
    assert_eq(int(entries[2]["ticks"]), 3)
    assert_eq(int(entries[0]["count"]), 1)


func test_two_cells_build_independent_summaries() -> void:
    var cell_a := Vector2i(0, 0)
    var cell_b := Vector2i(1, 1)
    var danger: Array[Dictionary] = [
        { "cells": [cell_a], "ticks": 1 },
        { "cells": [cell_b], "ticks": 4 },
        { "cells": [cell_b], "ticks": 4 },
    ]

    var summaries := TickGridView.aggregate_cell_summaries(danger)

    var entries_a: Array[Dictionary] = summaries[cell_a]
    var entries_b: Array[Dictionary] = summaries[cell_b]
    assert_eq(entries_a.size(), 1)
    assert_eq(int(entries_a[0]["count"]), 1)
    assert_eq(entries_b.size(), 1)
    assert_eq(int(entries_b[0]["count"]), 2)


func test_source_repeating_a_cell_contributes_only_one_count() -> void:
    var cell := Vector2i(3, 3)
    var danger: Array[Dictionary] = [
        { "cells": [cell, cell, cell], "ticks": 2 },
    ]

    var entries: Array[Dictionary] = TickGridView.aggregate_cell_summaries(danger)[cell]

    assert_eq(entries.size(), 1)
    assert_eq(int(entries[0]["count"]), 1, "one source repeating a cell should still count once")


func test_non_positive_or_missing_ticks_are_skipped() -> void:
    var cell := Vector2i(6, 6)
    var danger: Array[Dictionary] = [
        { "cells": [cell], "ticks": 0 },
        { "cells": [cell], "ticks": -1 },
        { "cells": [cell] },
    ]

    var summaries := TickGridView.aggregate_cell_summaries(danger)

    assert_false(summaries.has(cell), "invalid countdown payloads must not produce a label")


func test_no_danger_produces_no_summaries() -> void:
    var danger: Array[Dictionary] = []

    var summaries := TickGridView.aggregate_cell_summaries(danger)

    assert_true(summaries.is_empty(), "no valid danger should draw no countdown label")


func test_more_than_five_distinct_timers_keep_earliest_and_four_nearest() -> void:
    var cell := Vector2i(7, 7)
    var danger: Array[Dictionary] = [
        { "cells": [cell], "ticks": 6 },
        { "cells": [cell], "ticks": 1 },
        { "cells": [cell], "ticks": 5 },
        { "cells": [cell], "ticks": 2 },
        { "cells": [cell], "ticks": 4 },
        { "cells": [cell], "ticks": 3 },
    ]

    var entries: Array[Dictionary] = TickGridView.aggregate_cell_summaries(danger)[cell]

    assert_eq(entries.size(), 6, "aggregation keeps every distinct timer; draw-time capacity trims corners")
    var ticks_in_order: Array[int] = []
    for entry in entries:
        ticks_in_order.append(int(entry["ticks"]))
    assert_eq(ticks_in_order, [1, 2, 3, 4, 5, 6])


func test_player_occupied_cell_moves_primary_label_to_its_twelve_oclock_outer_ring() -> void:
    var cell := Vector2i(4, 4)
    var center := Vector2(512.0, 512.0)

    var badge_center := TickGridView.primary_countdown_label_center(center, cell, cell, 128.0)

    assert_eq(badge_center.x, center.x)
    assert_lt(badge_center.y, center.y)
    assert_almost_eq(badge_center.y, center.y - 128.0 * 0.43, 0.001)


func test_unoccupied_cell_keeps_primary_label_centered_on_its_tile() -> void:
    var target_cell := Vector2i(4, 4)
    var player_cell := Vector2i(5, 4)
    var center := Vector2(512.0, 512.0)

    var label_center := TickGridView.primary_countdown_label_center(center, target_cell, player_cell, 128.0)

    assert_eq(label_center, center)
