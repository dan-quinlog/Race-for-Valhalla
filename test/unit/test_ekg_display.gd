extends GutTest

var ekg: EkgDisplay


func before_each() -> void:
	ekg = EkgDisplay.new()
	ekg.size = Vector2(400, 120)
	add_child_autofree(ekg)
	ekg.configure(0.6, 0.15, 0.15, 0.04)


func test_final_markers_scroll_off_after_passing() -> void:
	ekg.add_final_marker(1.8, 0)
	ekg.add_final_marker(2.4, 1)
	assert_eq(ekg.final_marker_count(), 2)
	ekg.set_time(2.0)
	assert_eq(ekg.final_marker_count(), 2)
	ekg.set_time(1.8 + ekg.seconds_visible + 0.1)
	assert_eq(ekg.final_marker_count(), 1)


func test_configure_clears_final_markers() -> void:
	ekg.add_final_marker(1.0, 0)
	ekg.configure(0.6, 0.15, 0.15, 0.04)
	assert_eq(ekg.final_marker_count(), 0)


func test_wave_peaks_on_buh() -> void:
	assert_almost_eq(ekg.wave(0.0), 1.0, 0.05)
