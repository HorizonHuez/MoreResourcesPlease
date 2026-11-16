class_name NPCManager
extends RefCounted

var npcs: Dictionary = {}
var active_npc: NPCData
var supervisor_npc: NPCData
var warned_issues: Array[String] = []

func _init() -> void:
	npcs = NPCDatabase.get_all_npcs()
	supervisor_npc = npcs.get("elena_vance")

func get_npc_for_tier(tier: int) -> NPCData:
	warned_issues.clear()
	for npc in npcs.values():
		var data := npc as NPCData
		if data.assigned_tier == tier:
			active_npc = data
			return data
	return supervisor_npc

func get_average_reputation() -> float:
	var total: float = 0.0
	var count: int = 0
	for npc in npcs.values():
		var data := npc as NPCData
		total += float(data.reputation_current)
		count += 1
	return total / maxf(float(count), 1.0)

func evaluate_dialogue_condition(expression: String, ship_config: Dictionary, mission_def: MissionData, npc_state: NPCData) -> bool:
	if expression.strip_edges().is_empty():
		return true
	
	if "||" in expression:
		for part in expression.split("||"):
			if evaluate_dialogue_condition(part, ship_config, mission_def, npc_state):
				return true
		return false
	
	if "&&" in expression:
		for part in expression.split("&&"):
			if not evaluate_dialogue_condition(part, ship_config, mission_def, npc_state):
				return false
		return true
	
	var expr := expression.strip_edges()
	var operators := [">=", "<=", "==", "!=", ">", "<"]
	for op in operators:
		if op in expr:
			var tokens := expr.split(op, false, 1)
			if tokens.size() == 2:
				var lhs: Variant = _resolve_operand(tokens[0].strip_edges(), ship_config, mission_def, npc_state)
				var rhs: Variant = _resolve_operand(tokens[1].strip_edges(), ship_config, mission_def, npc_state)
				return _compare_values(lhs, rhs, op)
	return false

func _resolve_operand(token: String, cfg: Dictionary, m: MissionData, npc: NPCData) -> Variant:
	if token == "true": return true
	if token == "false": return false
	if token.is_valid_float(): return token.to_float()
	if token.begins_with("'") and token.ends_with("'"):
		return token.substr(1, token.length() - 2)
	
	match token:
		"config.budget": return float(cfg.get("budget", 0.0))
		"config.mass": return float(cfg.get("mass", 0.0))
		"config.delta_v": return float(cfg.get("calculated_delta_v", 0.0))
		"config.power": return float(cfg.get("power_watts", 0.0))
		"config.shielding": return float(cfg.get("radiation_shielding", 0.0))
		"config.has_solar": return bool(cfg.get("has_solar_panels", false))
		"config.has_rtg": return bool(cfg.get("has_rtg", false))
		"config.has_sar": return bool(cfg.get("has_sar", false))
		"config.has_neutron": return bool(cfg.get("has_neutron", false))
		"config.has_lunar_battery": return bool(cfg.get("has_lunar_battery", false))
		"config.has_autonomy": return bool(cfg.get("has_autonomy", false))
		"config.has_mars_solar": return bool(cfg.get("has_mars_solar", false))
		"config.has_ion": return bool(cfg.get("has_ion_thruster", false))
		"config.has_impactor": return bool(cfg.get("has_impactor", false))
		"config.has_high_gain_antenna": return bool(cfg.get("has_high_gain_antenna", false))
		"mission.max_budget": return m.max_budget_millions_usd if m else 0.0
		"mission.max_mass": return m.max_mass_kg if m else 0.0
		"mission.min_delta_v": return m.min_delta_v_ms if m else 0.0
		"mission.required_shielding": return (m.radiation_level * 0.8) if m else 0.0
		"npc.reputation": return npc.reputation_current if npc else 50
		"elena_reputation": return supervisor_npc.reputation_current if supervisor_npc else 50
		"average_reputation": return get_average_reputation()
	return 0

func _compare_values(a: Variant, b: Variant, op: String) -> bool:
	match op:
		"==": return a == b
		"!=": return a != b
		">=": return float(a) >= float(b)
		"<=": return float(a) <= float(b)
		">": return float(a) > float(b)
		"<": return float(a) < float(b)
	return false

func apply_dialogue_modifier(modifier: Dictionary, active_mission_def: MissionData) -> MissionData:
	var cloned := active_mission_def.duplicate(true) as MissionData
	var field: String = modifier.get("target_field", "")
	var op: String = modifier.get("operation", "SET")
	var val: Variant = modifier.get("value")
	
	if field == "flag":
		var flags: Array = cloned.get_meta("negotiated_flags", [])
		if not flags.has(val):
			flags.append(val)
		cloned.set_meta("negotiated_flags", flags)
		return cloned
	
	if field in cloned:
		var current_val: Variant = cloned.get(field)
		match op:
			"ADD": cloned.set(field, float(current_val) + float(val))
			"MULTIPLY": cloned.set(field, float(current_val) * float(val))
			"SET": cloned.set(field, val)
	return cloned

func on_part_removed(npc_id: String, removed_part: Dictionary, mission_def: MissionData) -> Dictionary:
	var npc: NPCData = npcs.get(npc_id, supervisor_npc)
	var part_id: String = removed_part.get("id", "")
	var part_name: String = tr(removed_part.get("name", "PART_DEFAULT_MODULE"))
	var reactions: Dictionary = npc.get_meta("removal_reactions", {})
	var flags: Array = mission_def.get_meta("negotiated_flags", []) if mission_def else []
	
	if reactions.has(part_id):
		var r: Dictionary = reactions[part_id]
		var mood: String = r.get("mood", "skeptical")
		var text: String = tr(r.get("text", ""))
		if (part_id == "ir_spec" or part_id == "sar_radar") and flags.has("m1_both_instruments"):
			mood = "alarmed"
			text = tr("REM_M1_BREACH") % part_name
		if (part_id == "neutron" or part_id == "stereo_cam") and flags.has("m2_high_res_bonus"):
			mood = "alarmed"
			text = tr("REM_M2_BREACH") % part_name
		return {"npc": npc, "mood": mood, "text": text}
	
	if bool(removed_part.get("is_instrument", false)):
		return {
			"npc": npc,
			"mood": "skeptical",
			"text": tr("REM_GENERIC_INSTRUMENT") % [part_name, mission_def.min_science_points]
		}
	
	return {
		"npc": supervisor_npc if supervisor_npc else npc,
		"mood": "neutral",
		"text": tr("REM_GENERIC_MODULE") % part_name
	}

func on_ship_config_updated(npc_id: String, ship_config: Dictionary, mission_def: MissionData) -> Dictionary:
	var candidates: Array[NPCData] = []
	if npcs.has(npc_id):
		candidates.append(npcs[npc_id] as NPCData)
	if supervisor_npc != null and supervisor_npc.npc_id != npc_id:
		candidates.append(supervisor_npc)
	
	var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
	for npc in candidates:
		for bark in npc.hangar_barks:
			var bark_id: String = bark.get("bark_id", "")
			var cond: String = bark.get("trigger_condition", "")
			var cooldown: float = float(bark.get("cooldown_seconds", 6))
			var last_time: float = float(npc.bark_cooldowns.get(bark_id, -999.0))
			
			if (now_sec - last_time) >= cooldown and evaluate_dialogue_condition(cond, ship_config, mission_def, npc):
				npc.bark_cooldowns[bark_id] = now_sec
				var mood: String = bark.get("mood", "neutral")
				if (mood == "alarmed" or mood == "skeptical") and not warned_issues.has(bark_id):
					warned_issues.append(bark_id)
				return {
					"npc": npc,
					"bark_id": bark_id,
					"mood": mood,
					"text": tr(bark.get("text", ""))
				}
	return {}

func resolve_mission_debrief(npc_id: String, simulation_result: Dictionary, active_mission_def: MissionData) -> Dictionary:
	var npc: NPCData = npcs.get(npc_id, supervisor_npc)
	var success: bool = bool(simulation_result.get("success", false))
	var unspent_budget: float = maxf(0.0, float(simulation_result.get("unspent_budget", 0.0)))
	var flags: Array = active_mission_def.get_meta("negotiated_flags", [])
	var rep_delta: int = 0
	var funds_delta: float = 0.0
	var citation_added: int = 0
	var budget_cut_next: bool = false
	var message: String = ""
	var mood: String = "celebrating"
	
	if success:
		rep_delta = 10
		if not flags.is_empty():
			rep_delta += 15
		if flags.has("m2_high_res_bonus"):
			rep_delta = int(round(float(rep_delta) * 1.5))
		funds_delta = 15.0 + roundf(unspent_budget * 0.25)
		message = tr("DEBRIEF_SUCCESS") % funds_delta
	else:
		mood = "alarmed"
		citation_added = 1
		budget_cut_next = true
		if not warned_issues.is_empty():
			rep_delta = -20
			funds_delta = -45.0
			message = tr("DEBRIEF_FAIL_NEGLIGENCE")
		else:
			rep_delta = -12
			funds_delta = -30.0
			message = tr("DEBRIEF_FAIL_OPERATIONAL")
	
	npc.reputation_current = clampi(npc.reputation_current + rep_delta, 0, 100)
	if supervisor_npc != null and supervisor_npc != npc:
		supervisor_npc.reputation_current = clampi(supervisor_npc.reputation_current + (5 if success else -8), 0, 100)
	
	return {
		"phase": "DEBRIEF_SUCCESS" if success else "DEBRIEF_FAIL",
		"mood": mood,
		"text": message,
		"reputation_delta": rep_delta,
		"new_reputation": npc.reputation_current,
		"funds_delta": funds_delta,
		"citation_added": citation_added,
		"budget_cut_next": budget_cut_next
	}
