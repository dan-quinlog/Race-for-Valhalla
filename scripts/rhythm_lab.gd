extends Control
## Rhythm Lab: a test bench for tuning the heartbeat feel. Press the four runes
## on the beat. Tempo and timing windows can be changed live.

const RUNE_ACTIONS: Array[StringName] = [&"rune_1", &"rune_2", &"rune_3", &"rune_4"]
## Placeholder names (the first four Elder Futhark runes). These are
## Latin-script on purpose, since runic glyphs may be missing from the font.
const RUNE_NAMES: Array[String] = ["Fehu", "Uruz", "Thurisaz", "Ansuz"]
const HISTORY_LENGTH: int = 8

var judge: BeatJudge
var combo := ComboTracker.new()
var history: Array[String] = []

@onready var _clock: BeatClock = %BeatClock
@onready var _ekg: EkgDisplay = %Ekg
@onready var _judgment_label: Label = %JudgmentLabel
@onready var _combo_label: Label = %ComboLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _history_label: Label = %HistoryLabel
@onready var _bpm: SpinBox = %Bpm
@onready var _window_ms: SpinBox = %WindowMs
@onready var _perfect_ms: SpinBox = %PerfectMs
@onready var _latency_ms: SpinBox = %LatencyMs
@onready var _rune_buttons: Array[Button] = [%Rune1, %Rune2, %Rune3, %Rune4]


func _ready() -> void:
	for i: int in _rune_buttons.size():
		_rune_buttons[i].button_down.connect(_on_rune_pressed.bind(i))
	for box: SpinBox in [_bpm, _window_ms, _perfect_ms, _latency_ms]:
		box.value_changed.connect(_on_setting_changed)
	%RestartButton.pressed.connect(restart)
	restart()


func restart() -> void:
	_clock.bpm = _bpm.value
	var period: float = HeartbeatAudio.actual_period(60.0 / _clock.bpm)
	# Keep neighbouring beats' windows from overlapping, and Perfect inside the window.
	var window: float = minf(_window_ms.value / 1000.0, period * 0.5 - 0.01)
	var perfect: float = minf(_perfect_ms.value / 1000.0, window)
	_clock.dum_delay = window
	_clock.input_latency = _latency_ms.value / 1000.0
	_clock.start()
	judge = BeatJudge.new(_clock.period, window, perfect)
	combo.reset()
	history.clear()
	_ekg.configure(_clock.period, window, window, perfect)
	_judgment_label.text = "Press on the beat"
	_refresh_labels()
	for box: SpinBox in [_bpm, _window_ms, _perfect_ms, _latency_ms]:
		box.get_line_edit().release_focus()


func submit_rune(rune: int, t: float) -> BeatJudge.Judgment:
	var j: BeatJudge.Judgment = judge.judge(t)
	combo.record(j.grade)
	_ekg.add_marker(t, j.grade)
	if j.grade != BeatJudge.Grade.MISS:
		history.append(RUNE_NAMES[rune])
		if history.size() > HISTORY_LENGTH:
			history.pop_front()
	_judgment_label.text = describe(j)
	_refresh_labels()
	return j


static func describe(j: BeatJudge.Judgment) -> String:
	var ms: int = roundi(j.offset * 1000.0)
	var timing: String = "%+d ms" % ms
	match j.grade:
		BeatJudge.Grade.PERFECT:
			return "PERFECT  (%s)" % timing
		BeatJudge.Grade.GOOD:
			return "GOOD  (%s %s)" % [timing, "early" if ms < 0 else "late"]
		_:
			if j.duplicate:
				return "MISS: one rune per beat"
			return "MISS  (%s)" % timing


func _refresh_labels() -> void:
	_combo_label.text = "Combo %d   (best %d)" % [combo.combo, combo.best]
	_stats_label.text = "Perfect %d   Good %d   Miss %d" % [combo.perfects, combo.goods, combo.misses]
	_history_label.text = "Runes: " + (" - ".join(history) if not history.is_empty() else "...")


func _process(_delta: float) -> void:
	_ekg.set_time(_clock.now())


func _unhandled_input(event: InputEvent) -> void:
	for i: int in RUNE_ACTIONS.size():
		if event.is_action_pressed(RUNE_ACTIONS[i]):
			_on_rune_pressed(i)
			get_viewport().set_input_as_handled()
			return


func _on_rune_pressed(rune: int) -> void:
	submit_rune(rune, _clock.input_time())


func _on_setting_changed(_value: float) -> void:
	restart()
