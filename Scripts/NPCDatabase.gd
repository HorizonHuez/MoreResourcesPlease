class_name NPCDatabase
extends RefCounted

static func get_all_npcs() -> Dictionary:
	var list: Array[NPCData] = [
		_build_elena_vance(),
		_build_camila_silva(),
		_build_kaori_arisaka(),
		_build_sofia_rostova(),
		_build_valeria_thorne(),
		_build_elena_mercer(),
		_build_clara_lin()
	]
	var map: Dictionary = {}
	for npc in list:
		map[npc.npc_id] = npc
	return map

static func _default_portraits() -> Dictionary:
	return {
		"neutral": "res://graphics/char/char_test_bust_04.png",
		"impressed": "res://graphics/char/char_test_bust_04.png",
		"skeptical": "res://graphics/char/char_test_bust_04.png",
		"alarmed": "res://graphics/char/char_test_bust_04.png",
		"celebrating": "res://graphics/char/char_test_bust_04.png"
	}

static func _build_elena_vance() -> NPCData:
	var n := NPCData.new()
	n.npc_id = "elena_vance"
	n.npc_name = "NPC_ELENA_NAME"
	n.role = "NPC_ELENA_ROLE"
	n.faction = "NPC_ELENA_FACTION"
	n.assigned_mission_id = ""
	n.assigned_tier = 0
	n.reputation_current = 55
	n.reputation_initial = 55
	n.portraits = _default_portraits()
	n.hangar_barks = [
		{
			"bark_id": "elena_budget_over",
			"trigger_condition": "config.budget > mission.max_budget",
			"mood": "alarmed",
			"text": "BARK_ELENA_BUDGET",
			"cooldown_seconds": 5
		},
		{
			"bark_id": "elena_mass_over",
			"trigger_condition": "config.mass > mission.max_mass",
			"mood": "alarmed",
			"text": "BARK_ELENA_MASS",
			"cooldown_seconds": 5
		},
		{
			"bark_id": "elena_dv_low",
			"trigger_condition": "config.delta_v < mission.min_delta_v && config.delta_v > 0",
			"mood": "skeptical",
			"text": "BARK_ELENA_DV",
			"cooldown_seconds": 6
		}
	]
	n.set_meta("removal_reactions", {
		"default": {"mood": "skeptical", "text": "REM_ELENA_DEFAULT"}
	})
	return n

static func _build_camila_silva() -> NPCData:
	var n := NPCData.new()
	n.npc_id = "camila_silva"
	n.npc_name = "NPC_SILVA_NAME"
	n.role = "NPC_SILVA_ROLE"
	n.faction = "NPC_SILVA_FACTION"
	n.assigned_mission_id = "m01_leo_sentinel"
	n.assigned_tier = 1
	n.portraits = _default_portraits()
	n.hangar_barks = [
		{
			"bark_id": "silva_sar_impressed",
			"trigger_condition": "config.has_sar == true",
			"mood": "impressed",
			"text": "BARK_SILVA_SAR",
			"cooldown_seconds": 10
		},
		{
			"bark_id": "silva_no_power",
			"trigger_condition": "config.has_solar == false || config.power <= 0",
			"mood": "alarmed",
			"text": "BARK_SILVA_POWER",
			"cooldown_seconds": 6
		}
	]
	n.set_meta("removal_reactions", {
		"sar_radar": {"mood": "alarmed", "text": "REM_SILVA_SAR"},
		"ir_spec": {"mood": "skeptical", "text": "REM_SILVA_IR"},
		"solar_std": {"mood": "alarmed", "text": "REM_SILVA_SOLAR_STD"},
		"solar_pro": {"mood": "skeptical", "text": "REM_SILVA_SOLAR_PRO"}
	})
	n.dialogue_tree = {
		"entry_node_id": "m1_briefing",
		"nodes": [
			{
				"node_id": "m1_briefing",
				"phase": "BRIEFING",
				"mood": "neutral",
				"speaker_text": "DLG_M1_BRIEFING",
				"choices": [
					{
						"choice_id": "m1_opt_a",
						"player_text": "DLG_M1_OPT_A",
						"effects": {"reputation_delta": 0, "mission_modifiers": []},
						"next_node_id": ""
					},
					{
						"choice_id": "m1_opt_b",
						"player_text": "DLG_M1_OPT_B",
						"effects": {
							"reputation_delta": 15,
							"mission_modifiers": [
								{"target_field": "max_budget_millions_usd", "operation": "ADD", "value": 25.0},
								{"target_field": "min_science_points", "operation": "SET", "value": 125},
								{"target_field": "flag", "operation": "SET", "value": "m1_both_instruments"}
							]
						},
						"next_node_id": ""
					},
					{
						"choice_id": "m1_opt_c",
						"player_text": "DLG_M1_OPT_C",
						"effects": {"reputation_delta": 5},
						"next_node_id": "m1_hint_node"
					}
				]
			},
			{
				"node_id": "m1_hint_node",
				"phase": "NEGOTIATION",
				"mood": "impressed",
				"speaker_text": "DLG_M1_HINT",
				"choices": [
					{
						"choice_id": "m1_hint_std",
						"player_text": "DLG_M1_HINT_STD",
						"effects": {"reputation_delta": 0, "mission_modifiers": []},
						"next_node_id": ""
					},
					{
						"choice_id": "m1_hint_amp",
						"player_text": "DLG_M1_HINT_AMP",
						"effects": {
							"reputation_delta": 15,
							"mission_modifiers": [
								{"target_field": "max_budget_millions_usd", "operation": "ADD", "value": 25.0},
								{"target_field": "min_science_points", "operation": "SET", "value": 125},
								{"target_field": "flag", "operation": "SET", "value": "m1_both_instruments"}
							]
						},
						"next_node_id": ""
					}
				]
			}
		]
	}
	return n

static func _build_kaori_arisaka() -> NPCData:
	var n := NPCData.new()
	n.npc_id = "kaori_arisaka"
	n.npc_name = "NPC_ARISAKA_NAME"
	n.role = "NPC_ARISAKA_ROLE"
	n.faction = "NPC_ARISAKA_FACTION"
	n.assigned_mission_id = "m02_lunar_seeker"
	n.assigned_tier = 2
	n.portraits = _default_portraits()
	n.hangar_barks = [
		{
			"bark_id": "arisaka_battery_low",
			"trigger_condition": "config.has_lunar_battery == false",
			"mood": "skeptical",
			"text": "BARK_ARISAKA_BAT",
			"cooldown_seconds": 6
		},
		{
			"bark_id": "arisaka_neutron_ok",
			"trigger_condition": "config.has_neutron == true",
			"mood": "impressed",
			"text": "BARK_ARISAKA_NEUTRON",
			"cooldown_seconds": 10
		}
	]
	n.set_meta("removal_reactions", {
		"neutron": {"mood": "alarmed", "text": "REM_ARISAKA_NEUTRON"},
		"stereo_cam": {"mood": "skeptical", "text": "REM_ARISAKA_STEREO"},
		"lunar_bat": {"mood": "alarmed", "text": "REM_ARISAKA_BAT"}
	})
	n.dialogue_tree = {
		"entry_node_id": "m2_briefing",
		"nodes": [
			{
				"node_id": "m2_briefing",
				"phase": "BRIEFING",
				"mood": "neutral",
				"speaker_text": "DLG_M2_BRIEFING",
				"choices": [
					{
						"choice_id": "m2_opt_a",
						"player_text": "DLG_M2_OPT_A",
						"effects": {"reputation_delta": 0, "mission_modifiers": []},
						"next_node_id": ""
					},
					{
						"choice_id": "m2_opt_b",
						"player_text": "DLG_M2_OPT_B",
						"effects": {
							"reputation_delta": 10,
							"mission_modifiers": [
								{"target_field": "min_science_points", "operation": "SET", "value": 130},
								{"target_field": "flag", "operation": "SET", "value": "m2_high_res_bonus"}
							]
						},
						"next_node_id": ""
					}
				]
			}
		]
	}
	return n

static func _build_sofia_rostova() -> NPCData:
	var n := NPCData.new()
	n.npc_id = "sofia_rostova"
	n.npc_name = "NPC_ROSTOVA_NAME"
	n.role = "NPC_ROSTOVA_ROLE"
	n.faction = "NPC_ROSTOVA_FACTION"
	n.assigned_mission_id = "m03_mars_pioneer"
	n.assigned_tier = 3
	n.portraits = _default_portraits()
	n.hangar_barks = [
		{
			"bark_id": "rostova_no_autonomy",
			"trigger_condition": "config.has_autonomy == false",
			"mood": "alarmed",
			"text": "BARK_ROSTOVA_AUTO",
			"cooldown_seconds": 6
		},
		{
			"bark_id": "rostova_dust_power",
			"trigger_condition": "config.has_mars_solar == false",
			"mood": "skeptical",
			"text": "BARK_ROSTOVA_DUST",
			"cooldown_seconds": 6
		}
	]
	n.set_meta("removal_reactions", {
		"edl_std": {"mood": "alarmed", "text": "REM_ROSTOVA_EDL_STD"},
		"edl_skycrane": {"mood": "alarmed", "text": "REM_ROSTOVA_SKYCRANE"},
		"mars_autonomy": {"mood": "alarmed", "text": "REM_ROSTOVA_AUTO"},
		"mars_meteo": {"mood": "skeptical", "text": "REM_ROSTOVA_METEO"}
	})
	n.dialogue_tree = {
		"entry_node_id": "m3_briefing",
		"nodes": [
			{
				"node_id": "m3_briefing",
				"phase": "BRIEFING",
				"mood": "neutral",
				"speaker_text": "DLG_M3_BRIEFING",
				"choices": [
					{
						"choice_id": "m3_elysium",
						"player_text": "DLG_M3_OPT_ELYSIUM",
						"effects": {"reputation_delta": 0, "mission_modifiers": []},
						"next_node_id": ""
					},
					{
						"choice_id": "m3_jezero",
						"player_text": "DLG_M3_OPT_JEZERO",
						"effects": {
							"reputation_delta": 20,
							"mission_modifiers": [
								{"target_field": "max_budget_millions_usd", "operation": "ADD", "value": 100.0},
								{"target_field": "flag", "operation": "SET", "value": "m3_jezero_landing"}
							]
						},
						"next_node_id": ""
					}
				]
			}
		]
	}
	return n

static func _build_valeria_thorne() -> NPCData:
	var n := NPCData.new()
	n.npc_id = "valeria_thorne"
	n.npc_name = "NPC_THORNE_NAME"
	n.role = "NPC_THORNE_ROLE"
	n.faction = "NPC_THORNE_FACTION"
	n.assigned_mission_id = "m04_jovian_tides"
	n.assigned_tier = 4
	n.portraits = _default_portraits()
	n.hangar_barks = [
		{
			"bark_id": "thorne_solar_forbidden",
			"trigger_condition": "config.has_solar == true",
			"mood": "alarmed",
			"text": "BARK_THORNE_SOLAR",
			"cooldown_seconds": 5
		},
		{
			"bark_id": "thorne_shield_low",
			"trigger_condition": "config.shielding < mission.required_shielding",
			"mood": "skeptical",
			"text": "BARK_THORNE_SHIELD",
			"cooldown_seconds": 6
		}
	]
	n.set_meta("removal_reactions", {
		"jov_solar": {"mood": "impressed", "text": "REM_THORNE_SOLAR"},
		"jov_rtg": {"mood": "alarmed", "text": "REM_THORNE_RTG"},
		"jov_shield_hi": {"mood": "alarmed", "text": "REM_THORNE_SHIELD_HI"},
		"europa_mag": {"mood": "skeptical", "text": "REM_THORNE_MAG"}
	})
	n.dialogue_tree = {
		"entry_node_id": "m4_briefing",
		"nodes": [
			{
				"node_id": "m4_briefing",
				"phase": "BRIEFING",
				"mood": "impressed",
				"speaker_text": "DLG_M4_BRIEFING",
				"choices": [
					{
						"choice_id": "m4_nominal",
						"player_text": "DLG_M4_OPT_NOMINAL",
						"effects": {"reputation_delta": 0},
						"next_node_id": ""
					},
					{
						"choice_id": "m4_io_flyby",
						"player_text": "DLG_M4_OPT_IO",
						"effects": {
							"reputation_delta": 15,
							"mission_modifiers": [
								{"target_field": "max_budget_millions_usd", "operation": "ADD", "value": 200.0},
								{"target_field": "radiation_level", "operation": "SET", "value": 1.18},
								{"target_field": "flag", "operation": "SET", "value": "m4_io_append_goal"}
							]
						},
						"next_node_id": ""
					}
				]
			}
		]
	}
	return n

static func _build_elena_mercer() -> NPCData:
	var n := NPCData.new()
	n.npc_id = "elena_mercer"
	n.npc_name = "NPC_MARCUS_NAME"
	n.role = "NPC_MARCUS_ROLE"
	n.faction = "NPC_MARCUS_FACTION"
	n.assigned_mission_id = "m05_neo_interceptor"
	n.assigned_tier = 5
	n.portraits = _default_portraits()
	n.hangar_barks = [
		{
			"bark_id": "marcus_ion_impressed",
			"trigger_condition": "config.has_ion == true",
			"mood": "impressed",
			"text": "BARK_MARCUS_ION",
			"cooldown_seconds": 10
		},
		{
			"bark_id": "marcus_no_impactor",
			"trigger_condition": "config.has_impactor == false",
			"mood": "alarmed",
			"text": "BARK_MARCUS_IMPACTOR",
			"cooldown_seconds": 6
		}
	]
	n.set_meta("removal_reactions", {
		"neo_impactor": {"mood": "alarmed", "text": "REM_MARCUS_IMPACTOR"},
		"neo_ion_std": {"mood": "skeptical", "text": "REM_MARCUS_ION_STD"},
		"neo_ion_pro": {"mood": "alarmed", "text": "REM_MARCUS_ION_PRO"}
	})
	n.dialogue_tree = {
		"entry_node_id": "m5_briefing",
		"nodes": [
			{
				"node_id": "m5_briefing",
				"phase": "BRIEFING",
				"mood": "neutral",
				"speaker_text": "DLG_M5_BRIEFING",
				"choices": [
					{
						"choice_id": "m5_recon",
						"player_text": "DLG_M5_OPT_RECON",
						"effects": {"reputation_delta": 0},
						"next_node_id": ""
					},
					{
						"choice_id": "m5_deflect",
						"player_text": "DLG_M5_OPT_DEFLECT",
						"effects": {
							"reputation_delta": 15,
							"mission_modifiers": [
								{"target_field": "min_delta_v_ms", "operation": "ADD", "value": 1200.0},
								{"target_field": "max_budget_millions_usd", "operation": "ADD", "value": 120.0},
								{"target_field": "flag", "operation": "SET", "value": "m5_deflection_test"}
							]
						},
						"next_node_id": ""
					}
				]
			}
		]
	}
	return n

static func _build_clara_lin() -> NPCData:
	var n := NPCData.new()
	n.npc_id = "clara_lin"
	n.npc_name = "NPC_LIN_NAME"
	n.role = "NPC_LIN_ROLE"
	n.faction = "NPC_LIN_FACTION"
	n.assigned_mission_id = "m06_heliopause_explorer"
	n.assigned_tier = 6
	n.portraits = _default_portraits()
	n.hangar_barks = [
		{
			"bark_id": "clara_mass_heavy",
			"trigger_condition": "config.mass > 850",
			"mood": "skeptical",
			"text": "BARK_LIN_MASS",
			"cooldown_seconds": 6
		},
		{
			"bark_id": "clara_no_antenna",
			"trigger_condition": "config.has_high_gain_antenna == false",
			"mood": "alarmed",
			"text": "BARK_LIN_ANTENNA",
			"cooldown_seconds": 6
		}
	]
	n.set_meta("removal_reactions", {
		"helio_comm_hi": {"mood": "alarmed", "text": "REM_LIN_ANTENNA"},
		"helio_rtg": {"mood": "alarmed", "text": "REM_LIN_RTG"},
		"helio_cosmic": {"mood": "skeptical", "text": "REM_LIN_COSMIC"}
	})
	n.dialogue_tree = {
		"entry_node_id": "m6_briefing",
		"nodes": [
			{
				"node_id": "m6_briefing",
				"phase": "BRIEFING",
				"mood": "neutral",
				"speaker_text": "DLG_M6_BRIEFING",
				"choices": [
					{
						"choice_id": "m6_std",
						"player_text": "DLG_M6_OPT_STD",
						"effects": {"reputation_delta": 0},
						"next_node_id": ""
					},
					{
						"choice_id": "m6_ultralight",
						"player_text": "DLG_M6_OPT_ULTRALIGHT",
						"requirement": "average_reputation >= 75",
						"effects": {
							"reputation_delta": 10,
							"mission_modifiers": [
								{"target_field": "flag", "operation": "SET", "value": "m6_ultralight_10pct"}
							]
						},
						"next_node_id": ""
					}
				]
			}
		]
	}
	return n
