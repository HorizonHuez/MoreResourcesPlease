extends Control

@onready var lbl_budget: RichTextLabel = %LblBudget
@onready var lbl_mass: RichTextLabel = %LblMass
@onready var lbl_science: RichTextLabel = %LblScience
@onready var lbl_power: RichTextLabel = %LblPower
@onready var rich_text: RichTextLabel = %RichTextLabel
@onready var choices_container: VBoxContainer = %ChoicesContainer

@onready var top_bar: HBoxContainer = get_node_or_null("TopBar")
@onready var director_rect: TextureRect = get_node_or_null("MarginContainer/VBoxContainer/CharacterHeader/Directora")
@onready var header_vbox: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/CharacterHeader/VBoxContainer")
var npc_badge_label: RichTextLabel
var npc_visuals: NPCVisuals
var hangar_visualizer: HangarVisualizer

@export_category("Hangar Visuals")
@export var company_logos: Array[Texture2D] = []

@export_category("Procedural Character Generation")
@export_group("Nodes")
@export var _char_base_body: TextureRect
@export var _char_face: TextureRect
@export var _char_iris: TextureRect
@export var _char_hair: TextureRect
@export var _char_clothing: TextureRect
@export_group("Assets")
@export var _hairs: Array[Texture2D]

var button_sfx_player: AudioStreamPlayer
var button_sfx_stream: AudioStreamWAV
var bgm_player: AudioStreamPlayer

var settings_button: Button
var dev_levels_button: Button
var settings_overlay: Control
var dev_levels_overlay: Control
var settings_title_lbl: Label
var settings_lang_lbl: Label
var settings_vol_lbl: Label
var btn_lang_en: Button
var btn_lang_es: Button
var btn_settings_reset: Button
var btn_settings_close: Button

var typewriter_tween: Tween
var is_typing: bool = false
var pending_choices_callback: Callable
const TYPEWRITER_CHAR_DELAY: float = 0.015

var all_missions: Array[MissionData] = []
var current_mission_index: int = 0
var current_npc: NPCData
var active_header_npc: NPCData
var current_mood: String = "neutral"
var current_phase: String = "DIRECTOR_INTRO"
var current_node_id: String = ""
var active_bark: Dictionary = {}

var active_hangar_category: String = ""

var current_flight_situation_key: String = ""
var current_flight_options: Array = []
var last_debrief_success: bool = false
var last_debrief_outcome_key: String = ""

var selected_instruments: Dictionary = {}
var selected_slots: Dictionary = {}

func _ready() -> void:
	randomize()
	SaveSystem.load_progress()
	
	var bg := get_node_or_null("Background") as Control
	if bg:
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	hangar_visualizer = HangarVisualizer.new()
	hangar_visualizer.company_logos = company_logos
	add_child(hangar_visualizer)
	move_child(hangar_visualizer, 1 if bg else 0)
	
	var margin := get_node_or_null("MarginContainer") as MarginContainer
	if margin:
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
	
	var vbox_main := get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	if vbox_main:
		vbox_main.add_theme_constant_override("separation", 6)
	
	if choices_container:
		choices_container.add_theme_constant_override("separation", 4)
	
	for lbl in [lbl_budget, lbl_mass, lbl_science, lbl_power]:
		lbl.bbcode_enabled = true
		lbl.fit_content = true
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	rich_text.bbcode_enabled = true
	rich_text.gui_input.connect(_on_rich_text_gui_input)
	var panel := rich_text.get_parent() as Control
	if panel:
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	_setup_button_audio()
	_setup_procedural_papers_bgm()
	_setup_npc_visuals()
	_setup_npc_header_badge()
	_setup_top_bar_controls()
	
	GameManager.resources_updated.connect(_update_top_bar)
	GameManager.language_changed.connect(_on_language_changed)
	
	all_missions = MissionDatabase.get_all_missions()
	_audit_missing_translations()
	_start_mission(SaveSystem.selected_start_mission)

func _audit_missing_translations() -> void:
	var missing: Array[String] = []
	for tier in range(1, 7):
		var cat := _get_catalog_for_tier(tier)
		for inst in cat["instruments"]:
			var k: String = inst["name"]
			if tr(k) == k and not missing.has(k):
				missing.append(k)
		for slot in cat["slots"]:
			for field in ["name", "category", "bonus_text"]:
				var k: String = slot.get(field, "")
				if not k.is_empty() and tr(k) == k and not missing.has(k):
					missing.append(k)
	for m in all_missions:
		for k in [m.mission_name, m.destination]:
			if tr(k) == k and not missing.has(k):
				missing.append(k)
	if not missing.is_empty():
		push_warning("[i18n] Claves faltantes en translations.csv: " + ", ".join(missing))

func _setup_button_audio() -> void:
	button_sfx_player = AudioStreamPlayer.new()
	button_sfx_player.bus = "Master"
	button_sfx_player.volume_db = -8.0
	add_child(button_sfx_player)
	
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
	
	button_sfx_stream = AudioStreamWAV.new()
	button_sfx_stream.format = AudioStreamWAV.FORMAT_16_BITS
	button_sfx_stream.mix_rate = sample_rate
	button_sfx_stream.stereo = false
	button_sfx_stream.data = data
	button_sfx_player.stream = button_sfx_stream

func _setup_procedural_papers_bgm() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	bgm_player.volume_db = -9.0
	add_child(bgm_player)
	
	var sample_rate: int = 22050
	var bpm: float = 78.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 16
	var total_samples: int = int(float(sample_rate) * beat_dur * float(total_beats))
	
	var drone_seq: Array[int] = [38, 38, 38, 38, 34, 34, 34, 34, 31, 31, 31, 31, 33, 33, 33, 33]
	var arp_seq: Array[int] = [62, 65, 69, 65, 62, 65, 70, 65, 62, 67, 70, 67, 61, 64, 69, 64]
	
	var data := PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var beat_pos: float = t / beat_dur
		var step: int = int(beat_pos) % total_beats
		var step_t: float = fmod(beat_pos, 1.0)
		
		var drone_midi: int = drone_seq[step]
		var drone_freq: float = 440.0 * pow(2.0, float(drone_midi - 69) / 12.0)
		var drone_wave: float = (sin(TAU * drone_freq * t) * 0.7 + sin(TAU * drone_freq * 0.5 * t) * 0.3) * 0.30
		
		var pulse: float = 0.0
		if step % 2 == 0 and step_t < 0.18:
			pulse = sin(TAU * 110.0 * t) * exp(-step_t * 24.0) * 0.25
		
		var arp_midi: int = arp_seq[step]
		var arp_freq: float = 440.0 * pow(2.0, float(arp_midi - 69) / 12.0)
		var arp_env: float = sin(PI * clampf(step_t, 0.0, 1.0)) * 0.85
		var arp_wave: float = (sin(TAU * arp_freq * t) * 0.75 + sin(TAU * arp_freq * 2.0 * t) * 0.25) * 0.16 * arp_env
		
		var mix: float = clampf(drone_wave + pulse + arp_wave, -1.0, 1.0)
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

func _play_button_click() -> void:
	if button_sfx_player != null and button_sfx_player.is_inside_tree():
		button_sfx_player.pitch_scale = randf_range(0.96, 1.05)
		button_sfx_player.play()

func _bind_button_sound(btn: Button) -> void:
	if btn != null:
		btn.pressed.connect(_play_button_click)

func _setup_npc_visuals() -> void:
	npc_visuals = NPCVisuals.new()
	npc_visuals._char_base_body = _char_base_body
	npc_visuals._char_face = _char_face
	npc_visuals._char_iris = _char_iris
	npc_visuals._char_hair = _char_hair
	npc_visuals._char_clothing = _char_clothing
	npc_visuals._director_sprite = director_rect
	
	if not _hairs.is_empty():
		npc_visuals.female_hairs = _hairs
	
	add_child(npc_visuals)

func _setup_npc_header_badge() -> void:
	if header_vbox == null:
		return
	for child in header_vbox.get_children():
		child.queue_free()
	
	npc_badge_label = RichTextLabel.new()
	npc_badge_label.bbcode_enabled = true
	npc_badge_label.fit_content = true
	npc_badge_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_vbox.add_child(npc_badge_label)

func _setup_top_bar_controls() -> void:
	# Tu botón Dev Levels para salto libre de niveles en pruebas
	dev_levels_button = Button.new()
	dev_levels_button.text = "🛠️ Dev Levels"
	_bind_button_sound(dev_levels_button)
	dev_levels_button.pressed.connect(func(): dev_levels_overlay.visible = true)
	if top_bar:
		top_bar.add_child(dev_levels_button)
	else:
		add_child(dev_levels_button)
	
	settings_button = Button.new()
	settings_button.text = tr("UI_BTN_SETTINGS")
	_bind_button_sound(settings_button)
	settings_button.pressed.connect(func(): settings_overlay.visible = true)
	if top_bar:
		top_bar.add_child(settings_button)
	else:
		add_child(settings_button)
	
	# Ventana de Configuración
	settings_overlay = ColorRect.new()
	settings_overlay.color = Color(0.0, 0.0, 0.0, 0.78)
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.visible = false
	add_child(settings_overlay)
	
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.add_child(center)
	
	var box_panel := PanelContainer.new()
	box_panel.custom_minimum_size = Vector2(420, 270)
	center.add_child(box_panel)
	
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 20)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 16)
	box_panel.add_child(pad)
	
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
	_bind_button_sound(btn_lang_en)
	btn_lang_en.pressed.connect(func(): GameManager.set_language("en"))
	lang_row.add_child(btn_lang_en)
	
	btn_lang_es = Button.new()
	btn_lang_es.text = "Español"
	btn_lang_es.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bind_button_sound(btn_lang_es)
	btn_lang_es.pressed.connect(func(): GameManager.set_language("es"))
	lang_row.add_child(btn_lang_es)
	
	settings_vol_lbl = Label.new()
	vbox.add_child(settings_vol_lbl)
	
	var vol_slider := HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 1.0
	vol_slider.step = 0.05
	vol_slider.value = 1.0
	vol_slider.value_changed.connect(func(val: float):
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(val, 0.0001)))
		AudioServer.set_bus_mute(0, val <= 0.001)
	)
	vbox.add_child(vol_slider)
	
	vbox.add_child(HSeparator.new())
	
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	vbox.add_child(action_row)
	
	btn_settings_reset = Button.new()
	btn_settings_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bind_button_sound(btn_settings_reset)
	btn_settings_reset.pressed.connect(func():
		settings_overlay.visible = false
		SaveSystem.reset_progress()
		GameManager.reset_campaign_state()
	)
	action_row.add_child(btn_settings_reset)
	
	btn_settings_close = Button.new()
	btn_settings_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bind_button_sound(btn_settings_close)
	btn_settings_close.pressed.connect(func(): settings_overlay.visible = false)
	action_row.add_child(btn_settings_close)
	
	# Ventana Flotante de Dev Levels (Acceso directo a las 6 misiones)
	dev_levels_overlay = ColorRect.new()
	dev_levels_overlay.color = Color(0.0, 0.0, 0.0, 0.85)
	dev_levels_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dev_levels_overlay.visible = false
	add_child(dev_levels_overlay)
	
	var dev_center := CenterContainer.new()
	dev_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dev_levels_overlay.add_child(dev_center)
	
	var dev_panel := PanelContainer.new()
	dev_panel.custom_minimum_size = Vector2(460, 360)
	dev_center.add_child(dev_panel)
	
	var dev_pad := MarginContainer.new()
	dev_pad.add_theme_constant_override("margin_left", 20)
	dev_pad.add_theme_constant_override("margin_right", 20)
	dev_pad.add_theme_constant_override("margin_top", 16)
	dev_pad.add_theme_constant_override("margin_bottom", 16)
	dev_panel.add_child(dev_pad)
	
	var dev_vbox := VBoxContainer.new()
	dev_vbox.add_theme_constant_override("separation", 8)
	dev_pad.add_child(dev_vbox)
	
	var dev_title := Label.new()
	dev_title.text = "🛠️ DEV LEVEL SELECTOR"
	dev_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dev_vbox.add_child(dev_title)
	
	dev_vbox.add_child(HSeparator.new())
	
	var missions := MissionDatabase.get_all_missions()
	for i in range(missions.size()):
		var m_data = missions[i]
		var btn := Button.new()
		var item_fmt := tr("UI_MISSION_ITEM")
		if item_fmt == "UI_MISSION_ITEM":
			item_fmt = "Misión %d: %s"
		btn.text = item_fmt % [i + 1, tr(m_data.mission_name)]
		_bind_button_sound(btn)
		var idx := i
		btn.pressed.connect(func():
			dev_levels_overlay.visible = false
			_start_mission(idx)
		)
		dev_vbox.add_child(btn)
	
	dev_vbox.add_child(HSeparator.new())
	
	var dev_close_btn := Button.new()
	var close_tr := tr("UI_BTN_CLOSE")
	dev_close_btn.text = "Cerrar" if close_tr == "UI_BTN_CLOSE" else close_tr
	_bind_button_sound(dev_close_btn)
	dev_close_btn.pressed.connect(func(): dev_levels_overlay.visible = false)
	dev_vbox.add_child(dev_close_btn)
	
	_refresh_settings_texts()

func _refresh_settings_texts() -> void:
	if settings_button:
		settings_button.text = tr("UI_BTN_SETTINGS")
	if settings_title_lbl:
		settings_title_lbl.text = tr("UI_SET_TITLE")
		settings_lang_lbl.text = tr("UI_SET_LANG_LABEL")
		settings_vol_lbl.text = tr("UI_SET_VOL_LABEL")
		btn_settings_reset.text = tr("UI_SET_RESET_BTN")
		btn_settings_close.text = tr("UI_SET_CLOSE_BTN")
		btn_lang_en.disabled = (GameManager.current_locale == "en")
		btn_lang_es.disabled = (GameManager.current_locale == "es")

func _on_language_changed(_locale: String) -> void:
	_refresh_settings_texts()
	_update_top_bar()
	_audit_missing_translations()
	
	match current_phase:
		"DIRECTOR_INTRO":
			_enter_director_intro_turn(false)
		"BRIEFING", "NEGOTIATION":
			_enter_dialogue_node(current_node_id, false)
		"HANGAR_REVIEW":
			_refresh_hangar_ui()
		"LAUNCH_CHECK":
			_enter_launch_check_phase(false)
		"OPERATION":
			_render_flight_decision_ui(false)
		"DEBRIEF_SUCCESS", "DEBRIEF_FAIL":
			_finish_mission_debrief(last_debrief_success, last_debrief_outcome_key, true, false)
		"TERMINATED":
			_trigger_game_over_screen(false)
		"CAMPAIGN_END":
			_show_campaign_completed_screen(false)

func _update_npc_card(npc: NPCData, mood: String, animate_portrait: bool = true) -> void:
	if npc == null:
		return
	active_header_npc = npc
	current_mood = mood
	var mood_colors := {
		"neutral": "#7ec8e3",
		"impressed": "#66ff66",
		"skeptical": "#ffd166",
		"alarmed": "#ff6666",
		"celebrating": "#66ff66"
	}
	var col: String = mood_colors.get(mood, "#7ec8e3")
	
	if npc_visuals != null:
		if current_phase in ["DIRECTOR_INTRO", "LAUNCH_CHECK", "DEBRIEF_SUCCESS", "DEBRIEF_FAIL", "TERMINATED", "CAMPAIGN_END"]:
			npc_visuals.show_director(mood, animate_portrait)
		else:
			var target_npc_id = current_npc.npc_id if (current_npc != null and current_phase == "HANGAR_REVIEW") else npc.npc_id
			npc_visuals.prepare_mission_client(target_npc_id)
	
	var funds_col := "#ff6666" if GameManager.agency_funds_millions < 25.0 else "#66ff66"
	var cit_col := "#ff6666" if GameManager.citations_count >= 2 else "#ffd166"
	var mood_tr := tr("MOOD_" + mood.to_upper())
	var phase_tr := tr("PHASE_" + current_phase)
	
	if npc_badge_label:
		npc_badge_label.text = (
			(tr("UI_NPC_CARD_LINE1") % [tr(npc.npc_name), tr(npc.role), npc.reputation_current, col, mood_tr]) + "\n" +
			(tr("UI_NPC_CARD_LINE2") % [funds_col, GameManager.agency_funds_millions, cit_col, GameManager.citations_count, GameManager.MAX_CITATIONS, phase_tr])
		)

func _start_mission(index: int) -> void:
	if GameManager.is_game_over():
		_trigger_game_over_screen()
		return
	
	if index >= all_missions.size():
		_show_campaign_completed_screen()
		return
	
	current_mission_index = index
	selected_instruments.clear()
	selected_slots.clear()
	active_bark.clear()
	active_hangar_category = ""
	
	var mission := all_missions[index]
	GameManager.load_mission(mission)
	current_npc = GameManager.npc_manager.get_npc_for_tier(mission.tier)
	
	if hangar_visualizer != null:
		hangar_visualizer.update_ship(mission.tier, selected_instruments, selected_slots)
	
	_update_top_bar()
	_enter_director_intro_turn(true)

func _enter_director_intro_turn(animate: bool = true) -> void:
	current_phase = "DIRECTOR_INTRO"
	var m := GameManager.current_mission
	var supervisor: NPCData = GameManager.npc_manager.supervisor_npc
	var has_cut: bool = m.get_meta("had_budget_cut", false)
	var is_frontier: bool = m.get_meta("is_frontier", m.tier >= 4)
	_update_npc_card(supervisor, "alarmed" if has_cut else ("skeptical" if is_frontier else "neutral"), animate)
	
	var sanction_txt := tr("UI_SANCTION_NOTICE") if has_cut else ""
	var frontier_txt := tr("UI_FRONTIER_NOTICE") if is_frontier else tr("UI_HISTORIC_NOTICE")
	var dossier_txt := tr("UI_NEW_DOSSIER") % [
		m.tier,
		tr(m.mission_name)
	]
	var params_txt := tr("UI_BASE_PARAMS") % [
		m.max_budget_millions_usd,
		m.max_mass_kg,
		m.min_delta_v_ms,
		m.min_science_points
	]
	
	var full_text := sanction_txt + frontier_txt + dossier_txt + params_txt
	_play_typewriter_text(full_text, animate, func():
		_clear_choices()
		_add_choice_button(tr("UI_BTN_CALL_CLIENT"), _enter_client_turn)
	)

func _enter_client_turn() -> void:
	var entry_id: String = current_npc.dialogue_tree.get("entry_node_id", "")
	_enter_dialogue_node(entry_id, true)

func _show_campaign_completed_screen(animate: bool = true) -> void:
	current_phase = "CAMPAIGN_END"
	_update_npc_card(GameManager.npc_manager.supervisor_npc, "celebrating", animate)
	var msg := tr("UI_CAMPAIGN_DONE") % [
		GameManager.agency_funds_millions,
		GameManager.citations_count,
		GameManager.MAX_CITATIONS,
		GameManager.npc_manager.get_average_reputation()
	]
	_play_typewriter_text(msg, animate, func():
		_clear_choices()
		_add_choice_button(tr("UI_BTN_NEW_CAMPAIGN"), func():
			SaveSystem.reset_progress()
			GameManager.reset_campaign_state()
		)
	)

func _enter_dialogue_node(node_id: String, animate: bool = true) -> void:
	current_node_id = node_id
	if node_id.is_empty():
		_enter_hangar_phase()
		return
	
	var nodes: Array = current_npc.dialogue_tree.get("nodes", [])
	var target_node: Dictionary = {}
	for n in nodes:
		if n.get("node_id", "") == node_id:
			target_node = n
			break
	
	if target_node.is_empty():
		_enter_hangar_phase()
		return
	
	current_phase = target_node.get("phase", "BRIEFING")
	var mood: String = target_node.get("mood", "neutral")
	_update_npc_card(current_npc, mood, animate)
	
	var client_msg := "[b]%s:[/b] «%s»" % [
		tr(current_npc.npc_name),
		tr(target_node.get("speaker_text", ""))
	]
	
	var choices: Array = target_node.get("choices", [])
	_play_typewriter_text(client_msg, animate, func():
		_clear_choices()
		for choice in choices:
			var req: String = choice.get("requirement", "")
			var unlocked: bool = GameManager.npc_manager.evaluate_dialogue_condition(
				req, GameManager.get_current_ship_config(), GameManager.current_mission, current_npc
			)
			var label := tr(choice.get("player_text", "UI_BTN_CONTINUE"))
			if unlocked:
				_add_choice_button(label, func(): _select_dialogue_choice(choice))
			else:
				_add_choice_button(tr("UI_BTN_LOCKED") % [req, label], func(): pass, true)
	)

func _select_dialogue_choice(choice: Dictionary) -> void:
	var effects: Dictionary = choice.get("effects", {})
	var rep_delta: int = int(effects.get("reputation_delta", 0))
	current_npc.reputation_current = clampi(current_npc.reputation_current + rep_delta, 0, 100)
	
	var modifiers: Array = effects.get("mission_modifiers", [])
	for mod in modifiers:
		GameManager.current_mission = GameManager.npc_manager.apply_dialogue_modifier(mod, GameManager.current_mission)
	
	_update_top_bar()
	var next_id: String = choice.get("next_node_id", "")
	_enter_dialogue_node(next_id, true)

func _enter_hangar_phase() -> void:
	current_phase = "HANGAR_REVIEW"
	active_hangar_category = ""
	_update_npc_card(current_npc, "neutral", true)
	_refresh_hangar_ui()

func _open_hangar_category(category_id: String) -> void:
	active_hangar_category = category_id
	_refresh_hangar_ui()

func _toggle_instrument(part: Dictionary) -> void:
	var id: String = part["id"]
	var removed_part: Dictionary = {}
	if selected_instruments.has(id):
		removed_part = selected_instruments[id]
		selected_instruments.erase(id)
	else:
		selected_instruments[id] = part
	_apply_loadout_and_audit(removed_part)

func _select_slot(slot_name: String, part: Dictionary) -> void:
	var removed_part: Dictionary = {}
	if selected_slots.has(slot_name):
		removed_part = selected_slots[slot_name]
		if selected_slots[slot_name]["id"] == part["id"]:
			selected_slots.erase(slot_name)
		else:
			selected_slots[slot_name] = part
	else:
		selected_slots[slot_name] = part
	_apply_loadout_and_audit(removed_part)

func _apply_loadout_and_audit(removed_part: Dictionary = {}) -> void:
	var parts: Array[Dictionary] = []
	for inst in selected_instruments.values():
		parts.append(inst)
	for slot_part in selected_slots.values():
		parts.append(slot_part)
	
	GameManager.recalculate_from_parts(parts)
	
	if hangar_visualizer != null and GameManager.current_mission != null:
		hangar_visualizer.update_ship(GameManager.current_mission.tier, selected_instruments, selected_slots)
	
	if not removed_part.is_empty():
		var removal_bark := GameManager.npc_manager.on_part_removed(
			current_npc.npc_id, removed_part, GameManager.current_mission
		)
		if not removal_bark.is_empty():
			active_bark = removal_bark
			_update_npc_card(removal_bark["npc"] as NPCData, removal_bark["mood"], true)
			_refresh_hangar_ui()
			return
	
	var bark := GameManager.npc_manager.on_ship_config_updated(
		current_npc.npc_id, GameManager.get_current_ship_config(), GameManager.current_mission
	)
	if not bark.is_empty():
		active_bark = bark
		_update_npc_card(bark["npc"] as NPCData, bark["mood"], true)
	else:
		_update_npc_card(current_npc, current_mood, false)
	
	_refresh_hangar_ui()

func _get_mission_categories(m: MissionData) -> Array[Dictionary]:
	var catalog := _get_catalog_for_tier(m.tier)
	var categories: Array[Dictionary] = [
		{"id": "instruments", "label_key": "CAT_INSTRUMENTS"}
	]
	var seen_slots: Dictionary = {}
	for slot_part in catalog["slots"]:
		var slot_id: String = slot_part["slot"]
		if not seen_slots.has(slot_id):
			seen_slots[slot_id] = true
			categories.append({
				"id": slot_id,
				"label_key": slot_part["category"]
			})
	return categories

func _get_category_label_key(m: MissionData, category_id: String) -> String:
	for cat in _get_mission_categories(m):
		if cat["id"] == category_id:
			return cat["label_key"]
	return "CAT_INSTRUMENTS"

func _refresh_hangar_ui() -> void:
	if typewriter_tween and typewriter_tween.is_valid():
		typewriter_tween.kill()
	is_typing = false
	rich_text.visible_ratio = 1.0
	
	var m := GameManager.current_mission
	_update_top_bar()
	
	var bark_banner := ""
	if not active_bark.is_empty():
		var speaker: NPCData = active_bark["npc"]
		var mood: String = active_bark["mood"]
		var b_col := "#66ff66" if mood == "impressed" else ("#ff6666" if mood == "alarmed" else ("#7ec8e3" if mood == "neutral" else "#ffd166"))
		bark_banner = "[color=%s][b]💬 %s (%s):[/b] «%s»[/color]\n\n" % [
			b_col, tr(speaker.npc_name), tr("MOOD_" + mood.to_upper()), tr(active_bark["text"])
		]
	
	var equipped_names: Array[String] = []
	for inst in selected_instruments.values():
		equipped_names.append(tr(inst["name"]))
	for slot_part in selected_slots.values():
		equipped_names.append(tr(slot_part["name"]))
	var loadout_str := tr("UI_NO_MODULES") if equipped_names.is_empty() else ", ".join(equipped_names)
	
	var is_frontier: bool = m.get_meta("is_frontier", m.tier >= 4)
	var era_badge := tr("UI_BADGE_FRONTIER") if is_frontier else tr("UI_BADGE_OPERATIONAL")
	
	var sub_prompt := ""
	if active_hangar_category.is_empty():
		sub_prompt = "\n" + tr("UI_HANGAR_SELECT_CAT")
	else:
		var cat_name := tr(_get_category_label_key(m, active_hangar_category)).to_upper()
		sub_prompt = "\n" + (tr("UI_HANGAR_EDITING_CAT") % cat_name)
	
	rich_text.text = (
		bark_banner +
		era_badge +
		(tr("UI_HANGAR_HEADER") % [m.tier, tr(m.mission_name).to_upper(), tr(m.destination)]) +
		(tr("UI_CURRENT_MANIFEST") % loadout_str) +
		(tr("UI_CONTRACT_LIMITS") % [m.min_delta_v_ms, m.min_science_points, m.radiation_level * 80.0]) +
		sub_prompt
	)
	rich_text.scroll_to_line(0)
	_build_categorized_catalog(m)

func _build_categorized_catalog(m: MissionData) -> void:
	_clear_choices()
	var catalog := _get_catalog_for_tier(m.tier)
	var flags: Array = m.get_meta("negotiated_flags", [])
	var mass_mult: float = 0.90 if flags.has("m6_ultralight_10pct") else 1.0
	
	if active_hangar_category.is_empty():
		for cat in _get_mission_categories(m):
			var cat_id: String = cat["id"]
			var cat_title := tr(cat["label_key"]).to_upper()
			var status_txt := tr("UI_CAT_EMPTY")
			
			if cat_id == "instruments":
				var cnt := selected_instruments.size()
				if cnt > 0:
					var names: Array[String] = []
					for inst in selected_instruments.values():
						names.append(tr(inst["name"]))
					status_txt = "%s (%s)" % [tr("UI_CAT_EQUIPPED") % cnt, ", ".join(names)]
			elif selected_slots.has(cat_id):
				var eq: Dictionary = selected_slots[cat_id]
				status_txt = "✓ %s ($%.0fM | %.0fkg)" % [
					tr(eq["name"]), eq["cost"], float(eq["mass"]) * mass_mult
				]
			
			_add_choice_button("[%s] — %s" % [cat_title, status_txt], func(): _open_hangar_category(cat_id))
		
		_add_choice_button(tr("UI_BTN_LAUNCH_CHECK"), func(): _enter_launch_check_phase(true))
		return
	
	if active_hangar_category == "instruments":
		for inst in catalog["instruments"]:
			var active: bool = selected_instruments.has(inst["id"])
			var tag := tr("UI_TAG_INSTALLED") if active else tr("UI_TAG_INSTRUMENT")
			var text := "%s %s ($%.0fM | %.0fkg | +%d Sci | %.0fW)" % [
				tag, tr(inst["name"]), inst["cost"], float(inst["mass"]) * mass_mult, inst["science"], inst["power"]
			]
			_add_choice_button(text, func(): _toggle_instrument(inst))
	else:
		for slot_part in catalog["slots"]:
			if slot_part["slot"] != active_hangar_category:
				continue
			var slot: String = slot_part["slot"]
			var active: bool = selected_slots.has(slot) and selected_slots[slot]["id"] == slot_part["id"]
			var tag := tr("UI_TAG_ACTIVE") if active else "[%s]" % tr(slot_part["category"]).to_upper()
			var text := "%s %s ($%.0fM | %.0fkg | %s)" % [
				tag, tr(slot_part["name"]), slot_part["cost"], float(slot_part["mass"]) * mass_mult, tr(slot_part["bonus_text"])
			]
			_add_choice_button(text, func(): _select_slot(slot, slot_part))
	
	_add_choice_button(tr("UI_BTN_BACK_CATEGORIES"), func(): _open_hangar_category(""))

func _enter_launch_check_phase(animate: bool = true) -> void:
	current_phase = "LAUNCH_CHECK"
	var config := GameManager.get_current_ship_config()
	var result := GameManager.validate_mission_design(config, GameManager.current_mission)
	var errors: Array[String] = result["errors"].duplicate()
	
	if GameManager.science_points < GameManager.current_mission.min_science_points:
		errors.append(tr("ERR_SCIENCE_LOW") % [GameManager.science_points, GameManager.current_mission.min_science_points])
	
	if errors.is_empty():
		_update_npc_card(GameManager.npc_manager.supervisor_npc, "impressed", animate)
		_play_typewriter_text(tr("UI_CHECK_APPROVED"), animate, func():
			_clear_choices()
			_add_choice_button(tr("UI_BTN_SIGN_LAUNCH"), func(): _start_flight_decision_phase(true))
			_add_choice_button(tr("UI_BTN_BACK_HANGAR"), _enter_hangar_phase)
		)
	else:
		_update_npc_card(GameManager.npc_manager.supervisor_npc, "alarmed", animate)
		var err_txt := ""
		for e in errors:
			err_txt += "• " + e + "\n"
		_play_typewriter_text(tr("UI_CHECK_BLOCKED") % err_txt, animate, func():
			_clear_choices()
			_add_choice_button(tr("UI_BTN_FIX_HANGAR"), _enter_hangar_phase)
			_add_choice_button(tr("UI_BTN_FORCE_LAUNCH"), func(): _start_flight_decision_phase(false))
		)

func _start_flight_decision_phase(design_is_sound: bool) -> void:
	current_phase = "OPERATION"
	_clear_choices()
	
	if not design_is_sound:
		_finish_mission_debrief(false, "OUTCOME_ILLEGAL_LAUNCH")
		return
	
	var m := GameManager.current_mission
	var flags: Array = m.get_meta("negotiated_flags", [])
	
	if m.tier == 2 and not GameManager.has_lunar_battery:
		_finish_mission_debrief(false, "OUTCOME_M2_ECLIPSE_FAIL")
		return
	if m.tier == 3 and flags.has("m3_jezero_landing") and not GameManager.has_skycrane:
		_finish_mission_debrief(false, "OUTCOME_M3_JEZERO_FAIL")
		return
	if m.tier == 4 and flags.has("m4_io_append_goal") and not GameManager.has_heavy_jovian_shield:
		_finish_mission_debrief(false, "OUTCOME_M4_IO_FAIL")
		return
	if m.tier == 5 and flags.has("m5_deflection_test") and not GameManager.has_pro_ion:
		_finish_mission_debrief(false, "OUTCOME_M5_DEFLECT_FAIL")
		return
	
	var scenario := _get_flight_scenario(m.tier, flags)
	current_flight_situation_key = scenario["situation"]
	current_flight_options = scenario["options"].duplicate()
	current_flight_options.shuffle()
	_render_flight_decision_ui(true)

func _render_flight_decision_ui(animate: bool = true) -> void:
	var m := GameManager.current_mission
	_update_npc_card(current_npc, "skeptical", animate)
	var msg := tr("UI_TELEMETRY_HEADER") % [
		tr(m.destination).to_upper(),
		tr(current_npc.npc_name),
		tr(current_flight_situation_key)
	]
	_play_typewriter_text(msg, animate, func():
		_clear_choices()
		var prefix_keys := ["UI_OPT_1", "UI_OPT_2", "UI_OPT_3"]
		for i in range(current_flight_options.size()):
			var opt: Dictionary = current_flight_options[i]
			var prefix := tr(prefix_keys[i]) if i < prefix_keys.size() else "[MANEUVER]"
			_add_choice_button("%s %s" % [prefix, tr(opt["label"])], func():
				_finish_mission_debrief(bool(opt["success"]), opt["outcome"])
			)
	)

func _finish_mission_debrief(success: bool, outcome_key: String, is_language_refresh: bool = false, animate: bool = true) -> void:
	last_debrief_success = success
	last_debrief_outcome_key = outcome_key
	
	if success:
		SaveSystem.unlock_mission(current_mission_index + 1)
	
	var unspent: float = GameManager.current_mission.max_budget_millions_usd - GameManager.spent_budget_millions
	var debrief := GameManager.npc_manager.resolve_mission_debrief(
		current_npc.npc_id,
		{"success": success, "unspent_budget": unspent},
		GameManager.current_mission
	)
	if not is_language_refresh:
		GameManager.apply_debrief_consequences(debrief)
	
	current_phase = debrief["phase"]
	_update_npc_card(current_npc, debrief["mood"], animate)
	
	var col := "#66ff66" if success else "#ff6666"
	var rep_sign := "+" if int(debrief["reputation_delta"]) >= 0 else ""
	var funds_val := float(debrief["funds_delta"])
	var funds_sign := "+" if funds_val >= 0.0 else ""
	var title_str := tr("UI_DEBRIEF_TITLE_OK") if success else tr("UI_DEBRIEF_TITLE_FAIL")
	
	var msg := (
		"[color=%s][b]%s[/b][/color]\n\n" % [col, title_str] +
		"%s\n\n" % tr(outcome_key) +
		"[b]%s:[/b] «%s»\n\n" % [tr(current_npc.npc_name), debrief["text"]] +
		(tr("UI_DEBRIEF_CONSEQ") % [
			rep_sign, debrief["reputation_delta"], funds_sign, funds_val, GameManager.citations_count, GameManager.MAX_CITATIONS
		])
	)
	
	_play_typewriter_text(msg, animate, func():
		_clear_choices()
		if GameManager.is_game_over():
			_add_choice_button(tr("UI_BTN_DISCIPLINARY"), func(): _trigger_game_over_screen(true))
		elif success:
			_add_choice_button(tr("UI_BTN_NEXT_CLIENT"), func(): _start_mission(current_mission_index + 1))
		else:
			_add_choice_button(tr("UI_BTN_RETRY_CUT"), func(): _start_mission(current_mission_index))
	)

func _trigger_game_over_screen(animate: bool = true) -> void:
	current_phase = "TERMINATED"
	_update_npc_card(GameManager.npc_manager.supervisor_npc, "alarmed", animate)
	var reason := tr("UI_GAMEOVER_CITATIONS") if GameManager.citations_count >= GameManager.MAX_CITATIONS else (tr("UI_GAMEOVER_BANKRUPT") % GameManager.agency_funds_millions)
	_play_typewriter_text(tr("UI_GAMEOVER_SCREEN") % reason, animate, func():
		_clear_choices()
		_add_choice_button(tr("UI_BTN_RESTART_CAREER"), func():
			SaveSystem.reset_progress()
			GameManager.reset_campaign_state()
		)
	)

func _update_top_bar() -> void:
	var m := GameManager.current_mission
	if m == null:
		return
	var b_col := "#ff6666" if GameManager.spent_budget_millions > m.max_budget_millions_usd else "#66ff66"
	var m_col := "#ff6666" if GameManager.current_mass_kg > m.max_mass_kg else "#66ff66"
	var s_col := "#66ff66" if GameManager.science_points >= m.min_science_points else "#ffd166"
	var p_col := "#ff6666" if GameManager.power_watts <= 0.0 else "#66ff66"
	
	lbl_budget.text = tr("UI_TOP_BUDGET") % [b_col, GameManager.spent_budget_millions, m.max_budget_millions_usd]
	lbl_mass.text = tr("UI_TOP_MASS") % [m_col, GameManager.current_mass_kg, m.max_mass_kg]
	lbl_science.text = tr("UI_TOP_SCIENCE") % [s_col, GameManager.science_points, m.min_science_points]
	lbl_power.text = tr("UI_TOP_POWER") % [p_col, GameManager.power_watts, GameManager.current_delta_v_ms, m.min_delta_v_ms]
	if active_header_npc != null:
		_update_npc_card(active_header_npc, current_mood, false)

func _get_catalog_for_tier(tier: int) -> Dictionary:
	match tier:
		1:
			return {
				"instruments": [
					{"id": "ir_spec", "name": "PART_IR_SPEC", "cost": 30.0, "mass": 50.0, "science": 40, "power": -15.0, "is_instrument": true},
					{"id": "sar_radar", "name": "PART_SAR_RADAR", "cost": 70.0, "mass": 120.0, "science": 85, "power": -30.0, "is_instrument": true},
					{"id": "optical_decoy", "name": "PART_OPTICAL_DECOY", "cost": 25.0, "mass": 90.0, "science": 65, "power": -20.0, "is_instrument": true}
				],
				"slots": [
					{"id": "solar_std", "slot": "power", "category": "CAT_POWER", "name": "PART_SOLAR_STD", "cost": 20.0, "mass": 45.0, "solar_watts": 110.0, "shielding": 0.15, "bonus_text": "+110W | 15%"},
					{"id": "solar_pro", "slot": "power", "category": "CAT_POWER", "name": "PART_SOLAR_PRO", "cost": 55.0, "mass": 95.0, "solar_watts": 240.0, "shielding": 0.25, "bonus_text": "+240W | 25%"},
					{"id": "prop_leo", "slot": "propulsion", "category": "CAT_PROPULSION", "name": "PART_PROP_LEO", "cost": 30.0, "mass": 220.0, "dv": 3600.0, "power": -10.0, "bonus_text": "+3600 m/s"},
					{"id": "prop_heavy", "slot": "propulsion", "category": "CAT_PROPULSION", "name": "PART_PROP_HEAVY", "cost": 65.0, "mass": 340.0, "dv": 4900.0, "power": -15.0, "bonus_text": "+4900 m/s"}
				]
			}
		2:
			return {
				"instruments": [
					{"id": "neutron", "name": "PART_NEUTRON", "cost": 45.0, "mass": 35.0, "science": 70, "power": -20.0, "is_instrument": true},
					{"id": "stereo_cam", "name": "PART_STEREO_CAM", "cost": 50.0, "mass": 65.0, "science": 60, "power": -25.0, "is_instrument": true},
					{"id": "lunar_radar", "name": "PART_LUNAR_RADAR", "cost": 95.0, "mass": 180.0, "science": 75, "power": -55.0, "is_instrument": true}
				],
				"slots": [
					{"id": "lunar_basic", "slot": "power", "category": "CAT_POWER", "name": "PART_LUNAR_BASIC", "cost": 40.0, "mass": 80.0, "solar_watts": 140.0, "shielding": 0.30, "bonus_text": "+140W | 30%"},
					{"id": "lunar_bat", "slot": "power", "category": "CAT_POWER", "name": "PART_LUNAR_BAT", "cost": 95.0, "mass": 180.0, "solar_watts": 190.0, "shielding": 0.40, "bonus_text": "+190W | 40%"},
					{"id": "prop_tli", "slot": "propulsion", "category": "CAT_PROPULSION", "name": "PART_PROP_TLI", "cost": 195.0, "mass": 860.0, "dv": 6400.0, "power": -20.0, "bonus_text": "+6400 m/s"}
				]
			}
		3:
			return {
				"instruments": [
					{"id": "mars_meteo", "name": "PART_MARS_METEO", "cost": 140.0, "mass": 90.0, "science": 110, "power": -25.0, "is_instrument": true},
					{"id": "mars_soil", "name": "PART_MARS_SOIL", "cost": 110.0, "mass": 75.0, "science": 85, "power": -20.0, "is_instrument": true},
					{"id": "mars_drill", "name": "PART_MARS_DRILL", "cost": 190.0, "mass": 160.0, "science": 120, "power": -45.0, "is_instrument": true}
				],
				"slots": [
					{"id": "edl_std", "slot": "defense", "category": "CAT_EDL", "name": "PART_EDL_STD", "cost": 200.0, "mass": 210.0, "heat_shield": true, "parachute": true, "power": -10.0, "bonus_text": "BONUS_SUITABLE_PLAINS"},
					{"id": "edl_skycrane", "slot": "defense", "category": "CAT_EDL", "name": "PART_EDL_SKYCRANE", "cost": 290.0, "mass": 255.0, "heat_shield": true, "parachute": true, "power": -15.0, "bonus_text": "BONUS_SUITABLE_CRATERS"},
					{"id": "mars_autonomy", "slot": "avionics", "category": "CAT_AVIONICS", "name": "PART_MARS_AUTONOMY", "cost": 90.0, "mass": 30.0, "power": -15.0, "bonus_text": "BONUS_LATENCY_OK"},
					{"id": "mars_solar_pro", "slot": "power", "category": "CAT_POWER", "name": "PART_MARS_SOLAR", "cost": 95.0, "mass": 75.0, "solar_watts": 240.0, "shielding": 0.50, "bonus_text": "BONUS_MARS_WATTS"},
					{"id": "mars_prop", "slot": "propulsion", "category": "CAT_PROPULSION", "name": "PART_MARS_PROP", "cost": 210.0, "mass": 365.0, "dv": 8000.0, "power": -10.0, "bonus_text": "+8000 m/s"}
				]
			}
		4:
			return {
				"instruments": [
					{"id": "europa_mag", "name": "PART_EUROPA_MAG", "cost": 260.0, "mass": 140.0, "science": 140, "power": -45.0, "is_instrument": true},
					{"id": "europa_spec", "name": "PART_EUROPA_SPEC", "cost": 250.0, "mass": 135.0, "science": 145, "power": -45.0, "is_instrument": true},
					{"id": "io_plasma", "name": "PART_IO_PLASMA", "cost": 310.0, "mass": 200.0, "science": 155, "power": -55.0, "is_instrument": true}
				],
				"slots": [
					{"id": "jov_solar", "slot": "power", "category": "CAT_POWER", "name": "PART_JOV_SOLAR", "cost": 120.0, "mass": 200.0, "solar_watts": 500.0, "bonus_text": "BONUS_FAILS_JUPITER"},
					{"id": "jov_rtg_std", "slot": "power", "category": "CAT_POWER", "name": "PART_JOV_RTG_STD", "cost": 250.0, "mass": 65.0, "rtg_watts": 130.0, "bonus_text": "BONUS_130W_TIGHT"},
					{"id": "jov_rtg", "slot": "power", "category": "CAT_POWER", "name": "PART_JOV_RTG", "cost": 350.0, "mass": 85.0, "rtg_watts": 300.0, "bonus_text": "BONUS_300W_CONST"},
					{"id": "jov_shield_low", "slot": "defense", "category": "CAT_SHIELDING", "name": "PART_JOV_SHIELD_LOW", "cost": 110.0, "mass": 190.0, "shielding": 0.50, "bonus_text": "BONUS_SHIELD_50_LOW"},
					{"id": "jov_shield_med", "slot": "defense", "category": "CAT_SHIELDING", "name": "PART_JOV_SHIELD_MED", "cost": 180.0, "mass": 340.0, "shielding": 0.80, "bonus_text": "BONUS_NO_IO"},
					{"id": "jov_shield_hi", "slot": "defense", "category": "CAT_SHIELDING", "name": "PART_JOV_SHIELD_HI", "cost": 340.0, "mass": 660.0, "shielding": 0.98, "bonus_text": "BONUS_IO_EUROPA"},
					{"id": "jov_prop_std", "slot": "propulsion", "category": "CAT_PROPULSION", "name": "PART_JOV_PROP_STD", "cost": 520.0, "mass": 2100.0, "dv": 12400.0, "power": -25.0, "bonus_text": "+12400 m/s"},
					{"id": "jov_prop", "slot": "propulsion", "category": "CAT_PROPULSION", "name": "PART_JOV_PROP", "cost": 600.0, "mass": 2250.0, "dv": 13400.0, "power": -35.0, "bonus_text": "+13400 m/s"}
				]
			}
		5:
			return {
				"instruments": [
					{"id": "neo_impactor", "name": "PART_NEO_IMPACTOR", "cost": 150.0, "mass": 360.0, "science": 135, "power": -25.0, "is_instrument": true},
					{"id": "neo_sonar", "name": "PART_NEO_SONAR", "cost": 120.0, "mass": 160.0, "science": 120, "power": -30.0, "is_instrument": true},
					{"id": "neo_lidar_heavy", "name": "PART_NEO_LIDAR", "cost": 190.0, "mass": 380.0, "science": 145, "power": -55.0, "is_instrument": true}
				],
				"slots": [
					{"id": "neo_solar_std", "slot": "power", "category": "CAT_POWER", "name": "PART_NEO_SOLAR_STD", "cost": 65.0, "mass": 95.0, "solar_watts": 155.0, "shielding": 0.25, "bonus_text": "BONUS_NEO_LOW"},
					{"id": "neo_solar_hi", "slot": "power", "category": "CAT_POWER", "name": "PART_NEO_SOLAR", "cost": 110.0, "mass": 150.0, "solar_watts": 280.0, "shielding": 0.40, "bonus_text": "BONUS_NEO_WATTS"},
					{"id": "neo_nav_ground", "slot": "avionics", "category": "CAT_AVIONICS", "name": "PART_NEO_NAV_GROUND", "cost": 40.0, "mass": 25.0, "power": -10.0, "bonus_text": "BONUS_NAV_BASIC"},
					{"id": "neo_nav_lidar", "slot": "avionics", "category": "CAT_AVIONICS", "name": "PART_NEO_NAV_LIDAR", "cost": 90.0, "mass": 45.0, "shielding": 0.05, "power": -25.0, "bonus_text": "BONUS_NAV_PROX"},
					{"id": "neo_chem_trap", "slot": "propulsion", "category": "CAT_PROPULSION", "name": "PART_NEO_CHEM_TRAP", "cost": 140.0, "mass": 520.0, "dv": 5700.0, "ion_thruster": false, "power": -15.0, "bonus_text": "BONUS_CHEM_LOW_ISP"},
					{"id": "neo_ion_std", "slot": "propulsion", "category": "CAT_PROPULSION", "name": "PART_NEO_ION_STD", "cost": 200.0, "mass": 460.0, "dv": 5650.0, "ion_thruster": true, "power": -85.0, "bonus_text": "+5650 m/s"},
					{"id": "neo_ion_pro", "slot": "propulsion", "category": "CAT_PROPULSION", "name": "PART_NEO_ION_PRO", "cost": 300.0, "mass": 640.0, "dv": 6600.0, "ion_thruster": true, "power": -115.0, "bonus_text": "+6600 m/s"}
				]
			}
		_:
			return {
				"instruments": [
					{"id": "helio_cosmic", "name": "PART_HELIO_COSMIC", "cost": 220.0, "mass": 65.0, "science": 135, "power": -25.0, "is_instrument": true},
					{"id": "helio_wind", "name": "PART_HELIO_WIND", "cost": 210.0, "mass": 60.0, "science": 125, "power": -20.0, "is_instrument": true},
					{"id": "helio_mag", "name": "PART_HELIO_MAG", "cost": 200.0, "mass": 55.0, "science": 120, "power": -20.0, "is_instrument": true},
					{"id": "helio_dust", "name": "PART_HELIO_DUST", "cost": 250.0, "mass": 90.0, "science": 140, "power": -35.0, "is_instrument": true}
				],
				"slots": [
					{"id": "helio_rtg_std", "slot": "power", "category": "CAT_POWER", "name": "PART_HELIO_RTG_STD", "cost": 310.0, "mass": 55.0, "rtg_watts": 145.0, "bonus_text": "BONUS_145W_TIGHT"},
					{"id": "helio_rtg", "slot": "power", "category": "CAT_POWER", "name": "PART_HELIO_RTG", "cost": 430.0, "mass": 70.0, "rtg_watts": 300.0, "bonus_text": "BONUS_300W_CONST"},
					{"id": "helio_comm_med", "slot": "defense", "category": "CAT_COMMS", "name": "PART_HELIO_COMM_MED", "cost": 200.0, "mass": 80.0, "shielding": 0.65, "power": -20.0, "bonus_text": "BONUS_SHIELD_65_WEAK"},
					{"id": "helio_comm_hi", "slot": "defense", "category": "CAT_COMMS", "name": "PART_HELIO_COMM", "cost": 360.0, "mass": 130.0, "shielding": 0.90, "bonus_text": "BONUS_SHIELD_90"},
					{"id": "helio_prop_conv", "slot": "propulsion", "category": "CAT_PROPULSION", "name": "PART_HELIO_PROP_CONV", "cost": 720.0, "mass": 410.0, "dv": 15200.0, "power": -15.0, "bonus_text": "+15200 m/s"},
					{"id": "helio_prop", "slot": "propulsion", "category": "CAT_PROPULSION", "name": "PART_HELIO_PROP", "cost": 890.0, "mass": 465.0, "dv": 16800.0, "power": -20.0, "bonus_text": "+16800 m/s"}
				]
			}

func _get_flight_scenario(tier: int, flags: Array) -> Dictionary:
	match tier:
		1:
			var both := flags.has("m1_both_instruments")
			return {
				"situation": "FLT_M1_SIT_EXT" if both else "FLT_M1_SIT_STD",
				"options": [
					{"label": "FLT_M1_OPT1_LBL", "success": true, "outcome": "FLT_M1_OPT1_OUT"},
					{"label": "FLT_M1_OPT2_LBL", "success": false, "outcome": "FLT_M1_OPT2_OUT"}
				]
			}
		2:
			var high_res := flags.has("m2_high_res_bonus")
			return {
				"situation": "FLT_M2_SIT_HR" if high_res else "FLT_M2_SIT_STD",
				"options": [
					{"label": "FLT_M2_OPT1_LBL", "success": true, "outcome": "FLT_M2_OPT1_OUT"},
					{"label": "FLT_M2_OPT2_LBL", "success": false, "outcome": "FLT_M2_OPT2_OUT"}
				]
			}
		3:
			var is_jezero := flags.has("m3_jezero_landing")
			return {
				"situation": "FLT_M3_SIT_JEZERO" if is_jezero else "FLT_M3_SIT_ELYSIUM",
				"options": [
					{
						"label": "FLT_M3_OPT1_LBL",
						"success": not is_jezero,
						"outcome": "FLT_M3_OPT1_OK" if not is_jezero else "FLT_M3_OPT1_FAIL"
					},
					{
						"label": "FLT_M3_OPT2_LBL",
						"success": is_jezero,
						"outcome": "FLT_M3_OPT2_OK" if is_jezero else "FLT_M3_OPT2_FAIL"
					}
				]
			}
		4:
			var io_goal := flags.has("m4_io_append_goal")
			return {
				"situation": "FLT_M4_SIT_IO" if io_goal else "FLT_M4_SIT_NOM",
				"options": [
					{
						"label": "FLT_M4_OPT1_LBL",
						"success": not io_goal,
						"outcome": "FLT_M4_OPT1_OK" if not io_goal else "FLT_M4_OPT1_FAIL"
					},
					{
						"label": "FLT_M4_OPT2_LBL",
						"success": io_goal,
						"outcome": "FLT_M4_OPT2_OK" if io_goal else "FLT_M4_OPT2_FAIL"
					}
				]
			}
		5:
			var deflect := flags.has("m5_deflection_test")
			return {
				"situation": "FLT_M5_SIT_DEF" if deflect else "FLT_M5_SIT_REC",
				"options": [
					{
						"label": "FLT_M5_OPT1_LBL",
						"success": not deflect,
						"outcome": "FLT_M5_OPT1_OK" if not deflect else "FLT_M5_OPT1_FAIL"
					},
					{
						"label": "FLT_M5_OPT2_LBL",
						"success": deflect,
						"outcome": "FLT_M5_OPT2_OK" if not deflect else "FLT_M5_OPT2_FAIL"
					}
				]
			}
		_:
			return {
				"situation": "FLT_M6_SIT",
				"options": [
					{"label": "FLT_M6_OPT1_LBL", "success": true, "outcome": "FLT_M6_OPT1_OUT"},
					{"label": "FLT_M6_OPT2_LBL", "success": false, "outcome": "FLT_M6_OPT2_OUT"}
				]
			}

func _add_choice_button(label_text: String, callback: Callable, disabled: bool = false) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.disabled = disabled
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bind_button_sound(btn)
	btn.pressed.connect(callback)
	choices_container.add_child(btn)

func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()

func _play_typewriter_text(bbcode_text: String, animate: bool, on_complete: Callable) -> void:
	if typewriter_tween and typewriter_tween.is_valid():
		typewriter_tween.kill()
	
	pending_choices_callback = on_complete
	rich_text.text = bbcode_text
	rich_text.scroll_to_line(0)
	
	if not animate:
		is_typing = false
		rich_text.visible_ratio = 1.0
		if pending_choices_callback.is_valid():
			var cb := pending_choices_callback
			pending_choices_callback = Callable()
			cb.call()
		return
	
	is_typing = true
	rich_text.visible_ratio = 0.0
	_clear_choices()
	_add_choice_button(tr("UI_BTN_SKIP_TEXT"), _skip_typewriter)
	
	var char_count: int = maxi(rich_text.get_parsed_text().length(), 1)
	var duration: float = clampf(float(char_count) * TYPEWRITER_CHAR_DELAY, 0.30, 2.0)
	
	typewriter_tween = create_tween()
	typewriter_tween.tween_property(rich_text, "visible_ratio", 1.0, duration)
	typewriter_tween.finished.connect(_on_typewriter_finished)

func _skip_typewriter() -> void:
	if not is_typing:
		return
	if typewriter_tween and typewriter_tween.is_valid():
		typewriter_tween.kill()
	rich_text.visible_ratio = 1.0
	_on_typewriter_finished()

func _on_typewriter_finished() -> void:
	is_typing = false
	rich_text.visible_ratio = 1.0
	if pending_choices_callback.is_valid():
		var cb := pending_choices_callback
		pending_choices_callback = Callable()
		cb.call()

func _on_rich_text_gui_input(event: InputEvent) -> void:
	if is_typing and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_skip_typewriter()
