extends CanvasLayer

var click_sfx_player: AudioStreamPlayer
var bgm_player: AudioStreamPlayer
var level_select_overlay: ColorRect
var settings_overlay: ColorRect

@onready var menu_container: VBoxContainer = get_node_or_null("Cont/Container")
@onready var btn_start: Button = get_node_or_null("Cont/Container/Start")
@onready var btn_settings: Button = get_node_or_null("Cont/Container/Settings")

var btn_missions: Button

var settings_title_lbl: Label
var settings_lang_lbl: Label
var settings_vol_lbl: Label
var btn_lang_en: Button
var btn_lang_es: Button
var btn_reset_save: Button
var btn_close_settings: Button

# Diccionario de respaldo bilingüe automático (por si aún no agregas las claves a translations.csv)
const I18N_FALLBACK := {
	"en": {
		"UI_BTN_START": "Start Game",
		"UI_BTN_MISSIONS": "🚀 Missions",
		"UI_BTN_SETTINGS": "⚙️ Settings",
		"UI_SELECT_MISSION_TITLE": "🚀 MISSION SELECTION",
		"UI_MISSION_ITEM": "Mission %d: %s",
		"UI_MISSION_LOCKED": "🔒 Mission %d: [Locked]",
		"UI_BTN_CLOSE": "Close",
		"UI_SET_TITLE": "SETTINGS",
		"UI_SET_LANG_LABEL": "Language:",
		"UI_SET_VOL_LABEL": "Master Volume:",
		"UI_SET_RESET_BTN": "Reset Progress",
		"UI_SET_CLOSE_BTN": "Close"
	},
	"es": {
		"UI_BTN_START": "Iniciar Juego",
		"UI_BTN_MISSIONS": "🚀 Misiones",
		"UI_BTN_SETTINGS": "⚙️ Ajustes",
		"UI_SELECT_MISSION_TITLE": "🚀 SELECCIÓN DE MISIONES",
		"UI_MISSION_ITEM": "Misión %d: %s",
		"UI_MISSION_LOCKED": "🔒 Misión %d: [Bloqueada]",
		"UI_BTN_CLOSE": "Cerrar",
		"UI_SET_TITLE": "CONFIGURACIÓN",
		"UI_SET_LANG_LABEL": "Idioma:",
		"UI_SET_VOL_LABEL": "Volumen General:",
		"UI_SET_RESET_BTN": "Reiniciar Progreso",
		"UI_SET_CLOSE_BTN": "Cerrar"
	}
}

func _t(key: String) -> String:
	var translated := tr(key)
	if translated != key:
		return translated
	var loc: String = GameManager.current_locale if "current_locale" in GameManager else TranslationServer.get_locale().left(2)
	if not I18N_FALLBACK.has(loc):
		loc = "en"
	return I18N_FALLBACK[loc].get(key, key)

func _ready() -> void:
	SaveSystem.load_progress()
	_setup_audio()
	_setup_robotic_dminor_bgm()
	_connect_existing_buttons()
	_setup_mission_select_ui()
	_setup_settings_ui()
	_refresh_texts()
	
	if GameManager.has_signal("language_changed"):
		GameManager.language_changed.connect(_on_language_changed)

func _on_language_changed(_loc: String) -> void:
	_refresh_texts()
	if level_select_overlay != null and level_select_overlay.visible:
		_open_mission_select_overlay()

func _setup_audio() -> void:
	click_sfx_player = AudioStreamPlayer.new()
	click_sfx_player.bus = "Master"
	click_sfx_player.volume_db = -8.0
	add_child(click_sfx_player)
	
	var sample_rate: int = 22050
	var duration: float = 0.045
	var sample_count: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	
	for i in range(sample_count):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 75.0)
		var freq: float = lerpf(880.0, 520.0, t / duration)
		var wave: float = sin(TAU * freq * t) * 0.65 + sin(TAU * freq * 1.5 * t) * 0.35
		var sample_int: int = clampi(int(wave * env * 24000.0), -32768, 32767)
		data.encode_s16(i * 2, sample_int)
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	click_sfx_player.stream = wav

func _setup_robotic_dminor_bgm() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	bgm_player.volume_db = -8.5
	add_child(bgm_player)
	
	var sample_rate: int = 22050
	var bpm: float = 96.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 16
	var total_samples: int = int(float(sample_rate) * beat_dur * float(total_beats))
	
	var bass_seq: Array[int] = [38, 38, 50, 38, 34, 34, 46, 34, 31, 31, 43, 31, 33, 33, 45, 33]
	var robo_seq: Array[int] = [62, 65, 69, 65, 62, 65, 70, 65, 62, 67, 70, 67, 61, 64, 69, 64]
	
	var data := PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var beat_pos: float = t / beat_dur
		var step: int = int(beat_pos) % total_beats
		var step_t: float = fmod(beat_pos, 1.0)
		
		var bass_midi: int = bass_seq[step]
		var bass_freq: float = 440.0 * pow(2.0, float(bass_midi - 69) / 12.0)
		var bass_env: float = exp(-step_t * 6.5)
		var sq_bass: float = clampf(sin(TAU * bass_freq * t) * 2.5, -1.0, 1.0)
		var bass_wave: float = sq_bass * bass_env * 0.34
		
		var lead_midi: int = robo_seq[step]
		var lead_freq: float = 440.0 * pow(2.0, float(lead_midi - 69) / 12.0)
		var lead_env: float = exp(-step_t * 4.5) * (1.0 if step_t < 0.72 else 0.0)
		var sq_lead: float = clampf(sin(TAU * lead_freq * t) * 3.0, -1.0, 1.0)
		var sub_lead: float = sin(TAU * lead_freq * 0.5 * t)
		var lead_wave: float = (sq_lead * 0.6 + sub_lead * 0.4) * lead_env * 0.22
		
		var mech_click: float = 0.0
		if step_t < 0.06:
			mech_click = clampf(sin(TAU * 180.0 * t) * 4.0, -1.0, 1.0) * exp(-step_t * 45.0) * 0.16
		
		var mix: float = clampf(bass_wave + lead_wave + mech_click, -1.0, 1.0)
		data.encode_s16(i * 2, int(mix * 28000.0))
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total_samples
	wav.data = data
	
	bgm_player.stream = wav
	bgm_player.play()

func _play_menu_click() -> void:
	if click_sfx_player != null and click_sfx_player.is_inside_tree():
		click_sfx_player.pitch_scale = randf_range(0.96, 1.05)
		click_sfx_player.play()

func _bind_btn(btn: Button) -> void:
	if btn != null and not btn.pressed.is_connected(_play_menu_click):
		btn.pressed.connect(_play_menu_click)

func _connect_existing_buttons() -> void:
	if btn_start != null:
		_bind_btn(btn_start)
		if not btn_start.pressed.is_connected(_on_start_pressed):
			btn_start.pressed.connect(_on_start_pressed)
	
	if btn_settings != null:
		_bind_btn(btn_settings)
		if not btn_settings.pressed.is_connected(_on_settings_pressed):
			btn_settings.pressed.connect(_on_settings_pressed)

func _setup_mission_select_ui() -> void:
	btn_missions = Button.new()
	btn_missions.name = "Missions"
	_bind_btn(btn_missions)
	btn_missions.pressed.connect(_open_mission_select_overlay)
	
	if menu_container != null:
		if btn_start != null:
			btn_missions.custom_minimum_size = btn_start.custom_minimum_size
			btn_missions.size_flags_horizontal = btn_start.size_flags_horizontal
			if btn_start.theme != null:
				btn_missions.theme = btn_start.theme
			if btn_start.has_theme_font_size_override("font_size"):
				btn_missions.add_theme_font_size_override("font_size", btn_start.get_theme_font_size("font_size"))
		menu_container.add_child(btn_missions)
		if btn_start != null:
			menu_container.move_child(btn_missions, btn_start.get_index() + 1)
	else:
		add_child(btn_missions)
	
	level_select_overlay = ColorRect.new()
	level_select_overlay.color = Color(0.0, 0.0, 0.0, 0.85)
	level_select_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_select_overlay.z_index = 100
	level_select_overlay.visible = false
	add_child(level_select_overlay)

func _open_mission_select_overlay() -> void:
	SaveSystem.load_progress()
	for child in level_select_overlay.get_children():
		child.queue_free()
	
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_select_overlay.add_child(center)
	
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 380)
	center.add_child(panel)
	
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 20)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(pad)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	pad.add_child(vbox)
	
	var title := Label.new()
	title.text = _t("UI_SELECT_MISSION_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	var missions := MissionDatabase.get_all_missions()
	for i in range(missions.size()):
		var m_data = missions[i]
		var btn := Button.new()
		var is_unlocked := i <= SaveSystem.max_unlocked_mission
		
		if is_unlocked:
			btn.text = _t("UI_MISSION_ITEM") % [i + 1, tr(m_data.mission_name)]
			_bind_btn(btn)
			var target_idx := i
			btn.pressed.connect(func():
				SaveSystem.selected_start_mission = target_idx
				_launch_main_scene()
			)
		else:
			btn.text = _t("UI_MISSION_LOCKED") % [i + 1]
			btn.disabled = true
			
		vbox.add_child(btn)
	
	vbox.add_child(HSeparator.new())
	
	var btn_close := Button.new()
	btn_close.text = _t("UI_BTN_CLOSE")
	_bind_btn(btn_close)
	btn_close.pressed.connect(func(): level_select_overlay.visible = false)
	vbox.add_child(btn_close)
	
	level_select_overlay.visible = true

func _setup_settings_ui() -> void:
	settings_overlay = ColorRect.new()
	settings_overlay.color = Color(0.0, 0.0, 0.0, 0.85)
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.z_index = 100
	settings_overlay.visible = false
	add_child(settings_overlay)
	
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.add_child(center)
	
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 270)
	center.add_child(panel)
	
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 20)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(pad)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	pad.add_child(vbox)
	
	settings_title_lbl = Label.new()
	settings_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(settings_title_lbl)
	
	vbox.add_child(HSeparator.new())
	
	settings_lang_lbl = Label.new()
	vbox.add_child(settings_lang_lbl)
	
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 10)
	vbox.add_child(lang_row)
	
	btn_lang_en = Button.new()
	btn_lang_en.text = "English"
	btn_lang_en.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bind_btn(btn_lang_en)
	btn_lang_en.pressed.connect(func():
		GameManager.set_language("en")
		_refresh_texts()
	)
	lang_row.add_child(btn_lang_en)
	
	btn_lang_es = Button.new()
	btn_lang_es.text = "Español"
	btn_lang_es.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bind_btn(btn_lang_es)
	btn_lang_es.pressed.connect(func():
		GameManager.set_language("es")
		_refresh_texts()
	)
	lang_row.add_child(btn_lang_es)
	
	settings_vol_lbl = Label.new()
	vbox.add_child(settings_vol_lbl)
	
	var vol_slider := HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 1.0
	vol_slider.step = 0.05
	vol_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	vol_slider.value_changed.connect(func(val: float):
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(val, 0.0001)))
		AudioServer.set_bus_mute(0, val <= 0.001)
	)
	vbox.add_child(vol_slider)
	
	vbox.add_child(HSeparator.new())
	
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	vbox.add_child(action_row)
	
	btn_reset_save = Button.new()
	btn_reset_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bind_btn(btn_reset_save)
	btn_reset_save.pressed.connect(func():
		SaveSystem.reset_progress()
		settings_overlay.visible = false
	)
	action_row.add_child(btn_reset_save)
	
	btn_close_settings = Button.new()
	btn_close_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bind_btn(btn_close_settings)
	btn_close_settings.pressed.connect(func(): settings_overlay.visible = false)
	action_row.add_child(btn_close_settings)

func _refresh_texts() -> void:
	if btn_start != null:
		btn_start.text = _t("UI_BTN_START")
	if btn_missions != null:
		btn_missions.text = _t("UI_BTN_MISSIONS")
	if btn_settings != null:
		btn_settings.text = _t("UI_BTN_SETTINGS")
	if settings_title_lbl != null:
		settings_title_lbl.text = _t("UI_SET_TITLE")
		settings_lang_lbl.text = _t("UI_SET_LANG_LABEL")
		settings_vol_lbl.text = _t("UI_SET_VOL_LABEL")
		btn_reset_save.text = _t("UI_SET_RESET_BTN")
		btn_close_settings.text = _t("UI_SET_CLOSE_BTN")
		btn_lang_en.disabled = (GameManager.current_locale == "en")
		btn_lang_es.disabled = (GameManager.current_locale == "es")

# ==============================================================================
# SEÑALES DE BOTONES DEL MENÚ
# ==============================================================================
func _on_start_pressed() -> void:
	SaveSystem.selected_start_mission = 0
	_launch_main_scene()

func _launch_main_scene() -> void:
	var main_scene := "res://scenes/Main.tscn" if ResourceLoader.exists("res://scenes/Main.tscn") else "res://Main.tscn"
	get_tree().change_scene_to_file(main_scene)

func _on_settings_pressed() -> void:
	if settings_overlay != null:
		settings_overlay.visible = true

func _on_back_pressed() -> void:
	if settings_overlay != null:
		settings_overlay.visible = false
	if level_select_overlay != null:
		level_select_overlay.visible = false

func _on_quit_pressed() -> void:
	get_tree().quit()
