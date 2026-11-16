extends Control

@onready var lbl_budget: RichTextLabel = %LblBudget
@onready var lbl_mass: RichTextLabel = %LblMass
@onready var lbl_science: RichTextLabel = %LblScience
@onready var lbl_power: RichTextLabel = %LblPower
@onready var rich_text: RichTextLabel = %RichTextLabel
@onready var choices_container: VBoxContainer = %ChoicesContainer

var all_missions: Array[MissionData] = []
var current_mission_index: int = 0

func _ready() -> void:
	for lbl in [lbl_budget, lbl_mass, lbl_science, lbl_power, rich_text]:
		lbl.bbcode_enabled = true
	
	GameManager.resources_updated.connect(_update_top_bar)
	all_missions = MissionDatabase.get_all_missions()
	_start_mission(0)

func _start_mission(index: int) -> void:
	if index >= all_missions.size():
		rich_text.text = "[b]¡CAMPAÑA COMPLETADA![/b]\nHas superado las 6 misiones de ingeniería espacial."
		_clear_choices()
		_add_choice_button("[JUGAR DE NUEVO]", func(): _start_mission(0))
		return
	
	current_mission_index = index
	var mission := all_missions[index]
	GameManager.load_mission(mission)
	
	_show_mission_briefing(mission)
	_build_mission_choices(mission)
	_update_top_bar()

func _update_top_bar() -> void:
	var m := GameManager.current_mission
	if m == null:
		return
	
	lbl_budget.text = "Presupuesto: $%.0fM / $%.0fM" % [GameManager.spent_budget_millions, m.max_budget_millions_usd]
	lbl_mass.text = "Masa: %.0f / %.0f kg" % [GameManager.current_mass_kg, m.max_mass_kg]
	lbl_science.text = "Ciencia: %d / %d pts" % [GameManager.science_points, m.min_science_points]
	lbl_power.text = "Energía: %.0f W (Δv: %.0f/%.0f m/s)" % [GameManager.power_watts, GameManager.current_delta_v_ms, m.min_delta_v_ms]

func _show_mission_briefing(m: MissionData) -> void:
	rich_text.text = (
		"[b]MISIÓN %d: %s[/b]\n" % [m.tier, m.mission_name.to_upper()] +
		"[color=#7ec8e3]Destino:[/color] %s\n" % m.destination +
		"[color=#7ec8e3]Objetivo:[/color] %s\n\n" % m.engineering_objective +
		"[b]Restricciones de Ingeniería:[/b]\n" +
		"• Delta-V Mínimo: %.0f m/s\n" % m.min_delta_v_ms +
		"• Latencia de Señal: %.1f min\n" % m.communication_latency_minutes +
		"• Radiación Ambiental: %.0f%%" % (m.radiation_level * 100.0)
	)

func _build_mission_choices(m: MissionData) -> void:
	_clear_choices()
	
	match m.tier:
		1: # Misión 1: Centinela Climático (LEO)
			_add_choice_button("Espectrómetro IR ($30M | 50kg | +40 Ciencia)", func():
				GameManager.active_instruments_count += 1
				GameManager.modify_resources(30.0, 50.0, 40, -15.0)
			)
			_add_choice_button("Radar de Apertura Sintética SAR ($70M | 120kg | +85 Ciencia)", func():
				GameManager.active_instruments_count += 1
				GameManager.modify_resources(70.0, 120.0, 85, -30.0)
			)
			_add_choice_button("Paneles Solares + Propulsor LEO ($35M | 180kg | +3600 m/s)", func():
				GameManager.has_solar_panels = true
				GameManager.radiation_shielding = 0.2
				GameManager.modify_resources(35.0, 180.0, 0, 120.0, 3600.0)
			)
			
		2: # Misión 2: Buscador Lunar (LLO)
			_add_choice_button("Espectrómetro de Neutrones ($45M | 35kg | +70 Ciencia)", func():
				GameManager.active_instruments_count += 1
				GameManager.modify_resources(45.0, 35.0, 70, -20.0)
			)
			_add_choice_button("Cámara Estereoscópica HR ($50M | 65kg | +60 Ciencia)", func():
				GameManager.active_instruments_count += 1
				GameManager.modify_resources(50.0, 65.0, 60, -25.0)
			)
			_add_choice_button("Propulsor Trans-Lunar TLI ($140M | 650kg | +6400 m/s)", func():
				GameManager.modify_resources(140.0, 650.0, 0, 0.0, 6400.0)
			)
			_add_choice_button("Paneles Solares + Baterías Eclipse + Blindaje ($65M | 150kg)", func():
				GameManager.has_solar_panels = true
				GameManager.radiation_shielding = 0.4
				GameManager.modify_resources(65.0, 150.0, 0, 150.0)
			)
			
		3: # Misión 3: Pionero Marciano (EDL)
			_add_choice_button("Sistema EDL: Escudo Térmico + Paracaídas + Retrorroques ($220M | 230kg)", func():
				GameManager.has_heat_shield = true
				GameManager.has_parachute = true
				GameManager.modify_resources(220.0, 230.0, 0, -10.0)
			)
			_add_choice_button("Etapa Interplanetaria + Frenado Terminal ($280M | 420kg | +8000 m/s)", func():
				GameManager.modify_resources(280.0, 420.0, 0, 0.0, 8000.0)
			)
			_add_choice_button("Estación Meteorológica Autónoma ($140M | 90kg | +110 Ciencia)", func():
				GameManager.active_instruments_count += 1
				GameManager.modify_resources(140.0, 90.0, 110, -25.0)
			)
			_add_choice_button("Analizador de Suelo y Polvo Marciano ($110M | 75kg | +85 Ciencia)", func():
				GameManager.active_instruments_count += 1
				GameManager.modify_resources(110.0, 75.0, 85, -20.0)
			)
			_add_choice_button("Paneles Reforzados + Blindaje Marciano ($70M | 65kg)", func():
				GameManager.has_solar_panels = true
				GameManager.radiation_shielding = 0.5
				GameManager.modify_resources(70.0, 65.0, 0, 110.0)
			)
			
		4: # Misión 4: Sonda de Mareas Jovianas (Europa)
			_add_choice_button("Generador RTG Plutonio-238 ($350M | 55kg | +300W)", func():
				GameManager.has_rtg = true
				GameManager.modify_resources(350.0, 55.0, 0, 300.0)
			)
			_add_choice_button("Bóveda de Blindaje Titanio/Plomo ($250M | 450kg | 100% Radiación)", func():
				GameManager.radiation_shielding = 1.0
				GameManager.modify_resources(250.0, 450.0, 0, 0.0)
			)
			_add_choice_button("Propulsión Asistida Venus-Tierra-Júpiter ($550M | 2100kg | +12800 m/s)", func():
				GameManager.modify_resources(550.0, 2100.0, 0, 0.0, 12800.0)
			)
			_add_choice_button("Magnetómetro de Océano Subsuperficial ($260M | 140kg | +140 Ciencia)", func():
				GameManager.active_instruments_count += 1
				GameManager.modify_resources(260.0, 140.0, 140, -40.0)
			)
			_add_choice_button("Espectrómetro de Mareas de Europa ($240M | 130kg | +130 Ciencia)", func():
				GameManager.active_instruments_count += 1
				GameManager.modify_resources(240.0, 130.0, 130, -35.0)
			)
			_add_choice_button("Paneles Solares Estándar ($40M | 60kg | Riesgo de fallo)", func():
				GameManager.has_solar_panels = true
				GameManager.modify_resources(40.0, 60.0, 0, 20.0)
			)
			
		5: # Misión 5: Interceptor de Asteroide Cercano (NEO)
			_add_choice_button("Motor Iónico Alto Isp >3000s ($180M | 450kg | +5500 m/s)", func():
				GameManager.has_ion_thruster = true
				GameManager.modify_resources(180.0, 450.0, 0, -60.0, 5500.0)
			)
			_add_choice_button("Impulsor Cinético de Superficie ($150M | 380kg | +130 Ciencia)", func():
				GameManager.active_instruments_count += 1
				GameManager.modify_resources(150.0, 380.0, 130, -20.0)
			)
			_add_choice_button("Sonar de Radar de Baja Frecuencia ($120M | 160kg | +110 Ciencia)", func():
				GameManager.active_instruments_count += 1
				GameManager.modify_resources(120.0, 160.0, 110, -25.0)
			)
			_add_choice_button("Paneles Solares Alta Eficiencia + Blindaje ($90M | 140kg | +250W)", func():
				GameManager.has_solar_panels = true
				GameManager.radiation_shielding = 0.35
				GameManager.modify_resources(90.0, 140.0, 0, 250.0)
			)
			
		6: # Misión 6: Explorador de la Heliopausa (120 AU)
			_add_choice_button("RTG de Larga Duración >15 años ($420M | 60kg | +280W)", func():
				GameManager.has_rtg = true
				GameManager.modify_resources(420.0, 60.0, 0, 280.0)
			)
			_add_choice_button("Etapas Sólidas Ultraligeras + Asistencia ($850M | 460kg | +16500 m/s)", func():
				GameManager.modify_resources(850.0, 460.0, 0, 0.0, 16500.0)
			)
			_add_choice_button("Antena Alta Ganancia + Blindaje Cósmico ($320M | 110kg)", func():
				GameManager.radiation_shielding = 0.9
				GameManager.modify_resources(320.0, 110.0, 0, -30.0)
			)
			_add_choice_button("Detector de Rayos Cósmicos Galácticos ($250M | 55kg | +130 Ciencia)", func():
				GameManager.active_instruments_count += 1
				GameManager.modify_resources(250.0, 55.0, 130, -20.0)
			)
			_add_choice_button("Analizador de Viento Solar Interestelar ($240M | 50kg | +125 Ciencia)", func():
				GameManager.active_instruments_count += 1
				GameManager.modify_resources(240.0, 50.0, 125, -20.0)
			)
			_add_choice_button("Magnetómetro de Heliopausa ($230M | 45kg | +120 Ciencia)", func():
				GameManager.active_instruments_count += 1
				GameManager.modify_resources(230.0, 45.0, 120, -15.0)
			)
	
	_add_choice_button("[REINICIAR DISEÑO ACTUAL]", func(): _start_mission(current_mission_index))
	_add_choice_button("[VALIDAR Y LANZAR MISIÓN]", _on_launch_pressed)

func _on_launch_pressed() -> void:
	var config := {
		"budget": GameManager.spent_budget_millions,
		"mass": GameManager.current_mass_kg,
		"calculated_delta_v": GameManager.current_delta_v_ms,
		"has_solar_panels": GameManager.has_solar_panels,
		"has_rtg": GameManager.has_rtg,
		"has_heat_shield": GameManager.has_heat_shield,
		"has_parachute": GameManager.has_parachute,
		"has_ion_thruster": GameManager.has_ion_thruster,
		"active_instruments": GameManager.active_instruments_count,
		"radiation_shielding": GameManager.radiation_shielding
	}
	
	var result := GameManager.validate_mission_design(config, GameManager.current_mission)
	var enough_science := GameManager.science_points >= GameManager.current_mission.min_science_points
	
	_show_mission_briefing(GameManager.current_mission)
	
	if result["is_valid"] and enough_science:
		rich_text.text += "\n\n[color=#66ff66][b]¡ÉXITO DE MISIÓN![/b] Todos los parámetros cumplen con las especificaciones.[/color]"
		_clear_choices()
		_add_choice_button("Siguiente Misión ->", func(): _start_mission(current_mission_index + 1))
	else:
		var error_log := "\n\n[color=#ff6666][b]FALLO EN VALIDACIÓN DE DISEÑO:[/b]\n"
		for err in result["errors"]:
			error_log += "• " + err + "\n"
		if not enough_science:
			error_log += "• Puntos de ciencia insuficientes (%d / %d)\n" % [GameManager.science_points, GameManager.current_mission.min_science_points]
		error_log += "[/color]"
		rich_text.text += error_log

func _add_choice_button(label_text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.pressed.connect(callback)
	choices_container.add_child(btn)

func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()
