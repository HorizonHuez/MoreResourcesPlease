extends Node

signal resources_updated
signal mission_loaded(mission: MissionData)
signal validation_completed(is_valid: bool, errors: Array[String])
signal language_changed(locale: String)

const NPCManagerScript = preload("res://Scripts/NPCManager.gd")
var npc_manager = NPCManagerScript.new()
var current_mission: MissionData
var current_locale: String = "en"

# Consecuencias persistentes estilo Papers, Please
var agency_funds_millions: float = 80.0
var citations_count: int = 0
const MAX_CITATIONS: int = 3
var next_budget_multiplier: float = 1.0

# Estado actual del diseño del jugador
var spent_budget_millions: float = 0.0
var current_mass_kg: float = 0.0
var current_delta_v_ms: float = 0.0
var science_points: int = 0
var power_watts: float = 0.0

# Sub-sistemas y banderas de piezas instaladas
var has_solar_panels: bool = false
var has_rtg: bool = false
var rtg_base_watts: float = 0.0
var solar_base_watts_at_1au: float = 0.0
var has_heat_shield: bool = false
var has_parachute: bool = false
var has_ion_thruster: bool = false
var radiation_shielding: float = 0.0
var active_instruments_count: int = 0

# Banderas específicas auditadas en el hangar y en vuelo
var has_sar: bool = false
var has_ir: bool = false
var has_neutron: bool = false
var has_stereo_cam: bool = false
var has_lunar_battery: bool = false
var has_autonomy: bool = false
var has_mars_solar: bool = false
var has_skycrane: bool = false
var has_heavy_jovian_shield: bool = false
var has_impactor: bool = false
var has_pro_ion: bool = false
var has_high_gain_antenna: bool = false

var drag_coefficient: float = 1.2
var cross_section_area_m2: float = 4.5

func _ready() -> void:
	set_language(current_locale)

func set_language(locale: String) -> void:
	current_locale = locale
	TranslationServer.set_locale(locale)
	emit_signal("language_changed", locale)

func reset_campaign_state() -> void:
	agency_funds_millions = 80.0
	citations_count = 0
	next_budget_multiplier = 1.0
	get_tree().change_scene_to_file("res://scenes/test_scene.tscn")
	#npc_manager = NPCManagerScript.new()

func load_mission(mission: MissionData) -> void:
	current_mission = mission.duplicate(true) as MissionData
	if next_budget_multiplier < 1.0:
		current_mission.max_budget_millions_usd = roundf(current_mission.max_budget_millions_usd * next_budget_multiplier)
		current_mission.set_meta("had_budget_cut", true)
		next_budget_multiplier = 1.0
	reset_design()
	emit_signal("mission_loaded", current_mission)

func apply_debrief_consequences(debrief: Dictionary) -> void:
	agency_funds_millions += float(debrief.get("funds_delta", 0.0))
	citations_count += int(debrief.get("citation_added", 0))
	if bool(debrief.get("budget_cut_next", false)):
		next_budget_multiplier = 0.85

func is_game_over() -> bool:
	return citations_count >= MAX_CITATIONS or agency_funds_millions < 0.0

func reset_design() -> void:
	spent_budget_millions = 0.0
	current_mass_kg = 0.0
	current_delta_v_ms = 0.0
	science_points = 0
	power_watts = 0.0
	has_solar_panels = false
	has_rtg = false
	rtg_base_watts = 0.0
	solar_base_watts_at_1au = 0.0
	has_heat_shield = false
	has_parachute = false
	has_ion_thruster = false
	radiation_shielding = 0.0
	active_instruments_count = 0
	has_sar = false
	has_ir = false
	has_neutron = false
	has_stereo_cam = false
	has_lunar_battery = false
	has_autonomy = false
	has_mars_solar = false
	has_skycrane = false
	has_heavy_jovian_shield = false
	has_impactor = false
	has_pro_ion = false
	has_high_gain_antenna = false
	emit_signal("resources_updated")

func recalculate_from_parts(parts: Array[Dictionary]) -> void:
	reset_design()
	var power_consumption: float = 0.0
	var flags: Array = current_mission.get_meta("negotiated_flags", []) if current_mission else []
	var mass_multiplier: float = 0.90 if flags.has("m6_ultralight_10pct") else 1.0
	
	for part in parts:
		var part_id: String = part.get("id", "")
		spent_budget_millions += float(part.get("cost", 0.0))
		current_mass_kg += float(part.get("mass", 0.0)) * mass_multiplier
		current_delta_v_ms += float(part.get("dv", 0.0))
		science_points += int(part.get("science", 0))
		
		var p_watts: float = float(part.get("power", 0.0))
		if p_watts < 0.0:
			power_consumption += absf(p_watts)
		
		if bool(part.get("is_instrument", false)):
			active_instruments_count += 1
		if float(part.get("solar_watts", 0.0)) > 0.0:
			has_solar_panels = true
			solar_base_watts_at_1au += float(part["solar_watts"])
		if float(part.get("rtg_watts", 0.0)) > 0.0:
			has_rtg = true
			rtg_base_watts += float(part["rtg_watts"])
		if bool(part.get("heat_shield", false)):
			has_heat_shield = true
		if bool(part.get("parachute", false)):
			has_parachute = true
		if bool(part.get("ion_thruster", false)):
			has_ion_thruster = true
		if part.has("shielding"):
			radiation_shielding = maxf(radiation_shielding, float(part["shielding"]))
		
		if part_id == "sar_radar": has_sar = true
		if part_id == "ir_spec": has_ir = true
		if part_id == "neutron": has_neutron = true
		if part_id == "stereo_cam": has_stereo_cam = true
		if part_id == "lunar_bat": has_lunar_battery = true
		if part_id == "mars_autonomy": has_autonomy = true
		if part_id == "mars_solar_pro": has_mars_solar = true
		if part_id == "edl_skycrane": has_skycrane = true
		if part_id == "jov_shield_hi": has_heavy_jovian_shield = true
		if part_id == "neo_impactor": has_impactor = true
		if part_id == "neo_ion_pro": has_pro_ion = true
		if part_id == "helio_comm_hi": has_high_gain_antenna = true
	
	var dist_au: float = current_mission.target_distance_au if current_mission else 1.0
	var env_state := update_environment({"required_power_watts": power_consumption}, {
		"distance_au": dist_au,
		"elapsed_years": 0.0,
		"in_eclipse": false,
		"dust_storm_factor": 1.0
	})
	power_watts = float(env_state["available_power_watts"]) - power_consumption
	emit_signal("resources_updated")

func get_current_ship_config() -> Dictionary:
	return {
		"budget": spent_budget_millions,
		"mass": current_mass_kg,
		"calculated_delta_v": current_delta_v_ms,
		"power_watts": power_watts,
		"has_solar_panels": has_solar_panels,
		"has_rtg": has_rtg,
		"has_heat_shield": has_heat_shield,
		"has_parachute": has_parachute,
		"has_ion_thruster": has_ion_thruster,
		"active_instruments": active_instruments_count,
		"radiation_shielding": radiation_shielding,
		"has_sar": has_sar,
		"has_ir": has_ir,
		"has_neutron": has_neutron,
		"has_stereo_cam": has_stereo_cam,
		"has_lunar_battery": has_lunar_battery,
		"has_autonomy": has_autonomy,
		"has_mars_solar": has_mars_solar,
		"has_skycrane": has_skycrane,
		"has_heavy_jovian_shield": has_heavy_jovian_shield,
		"has_impactor": has_impactor,
		"has_pro_ion": has_pro_ion,
		"has_high_gain_antenna": has_high_gain_antenna
	}

func validate_mission_design(config: Dictionary, mission_def: MissionData) -> Dictionary:
	var errors: Array[String] = []
	var flags: Array = mission_def.get_meta("negotiated_flags", [])
	
	if float(config.get("budget", 0.0)) > mission_def.max_budget_millions_usd:
		errors.append(tr("ERR_BUDGET_OVER") % [config["budget"], mission_def.max_budget_millions_usd])
	if float(config.get("mass", 0.0)) > mission_def.max_mass_kg:
		errors.append(tr("ERR_MASS_OVER") % [config["mass"], mission_def.max_mass_kg])
	if float(config.get("calculated_delta_v", 0.0)) < mission_def.min_delta_v_ms:
		errors.append(tr("ERR_DV_LOW") % [config["calculated_delta_v"], mission_def.min_delta_v_ms])
	if power_watts <= 0.0:
		errors.append(tr("ERR_POWER_LOW") % power_watts)
	if mission_def.forbids_solar_panels and bool(config.get("has_solar_panels", false)):
		errors.append(tr("ERR_SOLAR_FORBIDDEN") % tr(mission_def.destination))
	if mission_def.requires_rtg and not bool(config.get("has_rtg", false)):
		errors.append(tr("ERR_REQ_RTG"))
	if mission_def.requires_edl_system and (not bool(config.get("has_heat_shield", false)) or not bool(config.get("has_parachute", false))):
		errors.append(tr("ERR_REQ_EDL"))
	if mission_def.requires_ion_propulsion and not bool(config.get("has_ion_thruster", false)):
		errors.append(tr("ERR_REQ_ION"))
	if int(config.get("active_instruments", 0)) < mission_def.min_operational_instruments:
		errors.append(tr("ERR_INST_LOW") % [config.get("active_instruments", 0), mission_def.min_operational_instruments])
	if float(config.get("radiation_shielding", 0.0)) < (mission_def.radiation_level * 0.8):
		errors.append(tr("ERR_SHIELD_LOW") % [float(config.get("radiation_shielding", 0.0)) * 100.0, mission_def.radiation_level * 80.0])
	
	if flags.has("m1_both_instruments") and not (has_ir and has_sar):
		errors.append(tr("ERR_CLAUSE_M1"))
	if flags.has("m2_high_res_bonus") and not (has_neutron and has_stereo_cam):
		errors.append(tr("ERR_CLAUSE_M2"))
	if mission_def.tier == 3 and not has_autonomy:
		errors.append(tr("ERR_INSP_M3"))
	if mission_def.tier == 5 and not has_impactor:
		errors.append(tr("ERR_INSP_M5"))
	if mission_def.tier == 6 and not has_high_gain_antenna:
		errors.append(tr("ERR_INSP_M6"))

	var is_valid: bool = errors.is_empty()
	emit_signal("validation_completed", is_valid, errors)
	return {"is_valid": is_valid, "errors": errors}

func run_simulation_step(state: Dictionary, delta: float) -> Dictionary:
	if current_mission == null:
		return state
	var mass: float = maxf(float(state.get("mass_kg", current_mass_kg)), 1.0)
	var cd: float = maxf(float(state.get("cd", drag_coefficient)), 0.1)
	var area: float = maxf(float(state.get("area_m2", cross_section_area_m2)), 0.1)
	var velocity: float = float(state.get("velocity_ms", 0.0))
	var altitude: float = float(state.get("altitude_m", 0.0))
	var gravity: float = float(state.get("gravity_ms2", 3.72))
	
	var ballistic_coefficient: float = mass / (cd * area)
	state["ballistic_coefficient"] = ballistic_coefficient
	
	var rho: float = current_mission.atmospheric_density_kg_m3
	if rho > 0.0 and altitude > 0.0:
		var drag_deceleration: float = (rho * velocity * velocity) / (2.0 * ballistic_coefficient)
		velocity = maxf(0.0, velocity + (gravity - drag_deceleration) * delta)
		altitude = maxf(0.0, altitude - velocity * delta)
		state["thermal_load"] = 0.5 * rho * pow(velocity, 3.0) * 0.0001
	
	state["velocity_ms"] = velocity
	state["altitude_m"] = altitude
	return state

func update_environment(state: Dictionary, environment: Dictionary) -> Dictionary:
	var distance_au: float = maxf(float(environment.get("distance_au", 1.0)), 0.05)
	var elapsed_years: float = float(environment.get("elapsed_years", 0.0))
	var in_eclipse: bool = bool(environment.get("in_eclipse", false))
	var dust_factor: float = clampf(float(environment.get("dust_storm_factor", 1.0)), 0.0, 1.0)
	
	var generated_watts: float = 0.0
	if has_solar_panels and not in_eclipse:
		generated_watts += (solar_base_watts_at_1au / pow(distance_au, 2.0)) * dust_factor
	if has_rtg:
		generated_watts += rtg_base_watts * exp(-0.0079 * elapsed_years)
	
	state["available_power_watts"] = generated_watts
	state["power_balance_positive"] = generated_watts >= float(state.get("required_power_watts", 50.0))
	return state
