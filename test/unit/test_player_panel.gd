extends GutTest

const PanelScene: PackedScene = preload("res://scenes/player_panel.tscn")
const PERIOD: float = 0.6

var panel: PlayerPanel


func before_each() -> void:
	panel = PanelScene.instantiate()
	add_child_autofree(panel)
	panel.configure(PERIOD, 0.15, 0.04)


func _label(node_name: String) -> String:
	return panel.get_node("%" + node_name).text


func test_first_rune_marks_pad_pending() -> void:
	panel.submit(Rune.Dir.LEFT, PERIOD)
	assert_eq(panel.get_node("%RunePad").pending, Rune.Dir.LEFT)
	assert_eq(_label("ActionLabel"), "Attack...")


func test_completed_command_is_shown_and_logged() -> void:
	watch_signals(panel)
	panel.submit(Rune.Dir.LEFT, PERIOD)
	panel.submit(Rune.Dir.UP, PERIOD * 2)
	assert_eq(_label("ActionLabel"), "Heavy attack  PERFECT")
	assert_eq(panel.log_lines, ["Heavy attack  PERFECT"])
	assert_eq(panel.get_node("%RunePad").pending, CommandReader.NO_RUNE)
	assert_signal_emit_count(panel, "acted", 1)
	assert_signal_emit_count(panel, "judged", 2)


func test_prayer_updates_status() -> void:
	panel.submit(Rune.Dir.UP, PERIOD)
	panel.submit(Rune.Dir.DOWN, PERIOD * 2)
	assert_string_contains(_label("StatusLabel"), "Blessed: Movement")
	panel.submit(Rune.Dir.UP, PERIOD * 3)
	panel.submit(Rune.Dir.UP, PERIOD * 4)
	assert_string_starts_with(_label("StatusLabel"), "Glory 2")


func test_skipped_beat_drops_pending_command() -> void:
	panel.submit(Rune.Dir.RIGHT, PERIOD)
	panel.on_beat(3)
	assert_eq(panel.get_node("%RunePad").pending, CommandReader.NO_RUNE)
	assert_string_contains(_label("ActionLabel"), "queue cleared")


func test_skipped_beat_clears_queue_as_soon_as_it_closes() -> void:
	watch_signals(panel)
	panel.submit(Rune.Dir.RIGHT, PERIOD * 4)
	assert_signal_emitted_with_parameters(panel, "pending_changed", [Rune.Dir.RIGHT, 0])
	panel.on_beat_closed(4)
	assert_eq(panel.get_node("%RunePad").pending, Rune.Dir.RIGHT)
	panel.on_beat_closed(5)
	assert_eq(panel.get_node("%RunePad").pending, CommandReader.NO_RUNE)
	assert_string_contains(_label("ActionLabel"), "queue cleared")
	assert_signal_emitted_with_parameters(panel, "pending_changed", [CommandReader.NO_RUNE, 0])
	assert_true(panel.submit(Rune.Dir.LEFT, PERIOD * 6).started_command, "a fresh command")


func test_completed_command_clears_pending_signal() -> void:
	panel.submit(Rune.Dir.DOWN, PERIOD)
	watch_signals(panel)
	panel.submit(Rune.Dir.LEFT, PERIOD * 2)
	assert_signal_emitted_with_parameters(panel, "pending_changed", [CommandReader.NO_RUNE, 0])


func test_log_is_capped() -> void:
	for i: int in 7:
		panel.submit(Rune.Dir.DOWN, PERIOD * (2 * i + 1))
		panel.submit(Rune.Dir.LEFT, PERIOD * (2 * i + 2))
	assert_eq(panel.log_lines.size(), PlayerPanel.LOG_LENGTH)


func test_describe_reports_early_and_duplicate() -> void:
	var early := BeatJudge.Judgment.new(BeatJudge.Grade.GOOD, 1, -0.08)
	assert_eq(PlayerPanel.describe(early), "GOOD (-80 ms early)")
	var dup := BeatJudge.Judgment.new(BeatJudge.Grade.MISS, 1, 0.0, true)
	assert_eq(PlayerPanel.describe(dup), "MISS: one rune per beat")


func test_final_mode_shows_options_and_emits_strike() -> void:
	watch_signals(panel)
	var damage: Array[int] = [30, 25, 60, 40]
	panel.begin_final(6, damage)
	assert_string_contains(panel.get_node("%RunePad").button_text(Rune.Dir.LEFT), "Flurry 60")
	assert_eq(PlayerPanel.best_final(damage), Rune.Dir.LEFT)
	panel.on_beat(6)
	assert_eq(_label("ActionLabel"), "FINAL STRIKE NOW!")
	panel.submit(Rune.Dir.UP, PERIOD * 6)
	assert_signal_emitted_with_parameters(panel, "final_struck", [Rune.Dir.UP, 6, true, false, 0])
	assert_signal_emit_count(panel, "acted", 0)
	panel.end_final()
	assert_string_starts_with(_label("ActionLabel"), "Fallen")
	assert_true(panel.get_node("%RunePad").final_labels.is_empty())


func test_best_final_prefers_strike_on_ties() -> void:
	var none: Array[int] = [0, 0, 0, 0]
	assert_eq(PlayerPanel.best_final(none), Rune.Dir.DOWN)
