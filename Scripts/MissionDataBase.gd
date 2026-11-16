class_name MissionDatabase
extends RefCounted

static func get_all_missions() -> Array[MissionData]:
	var missions: Array[MissionData] = []
	
	# ==========================================================================
	# MISIONES 1–3: BASE ESTÁNDAR / ERA OPERATIVA
	# ==========================================================================
	var m1 := MissionData.new()
	m1.tier = 1
	m1.mission_id = "m01_leo_sentinel"
	m1.mission_name = "MISSION_1_NAME"
	m1.destination = "DEST_M1"
	m1.max_budget_millions_usd = 175.0
	m1.max_mass_kg = 500.0
	m1.min_delta_v_ms = 3500.0
	m1.target_distance_au = 1.0
	m1.min_science_points = 125
	m1.radiation_level = 0.10
	m1.min_operational_instruments = 1
	m1.set_meta("is_frontier", false)
	missions.append(m1)
	
	var m2 := MissionData.new()
	m2.tier = 2
	m2.mission_id = "m02_lunar_seeker"
	m2.mission_name = "MISSION_2_NAME"
	m2.destination = "DEST_M2"
	m2.max_budget_millions_usd = 420.0
	m2.max_mass_kg = 1250.0
	m2.min_delta_v_ms = 6000.0
	m2.target_distance_au = 1.0
	m2.min_science_points = 130
	m2.radiation_level = 0.35
	m2.min_operational_instruments = 1
	m2.set_meta("is_frontier", false)
	missions.append(m2)
	
	var m3 := MissionData.new()
	m3.tier = 3
	m3.mission_id = "m03_mars_pioneer"
	m3.mission_name = "MISSION_3_NAME"
	m3.destination = "DEST_M3"
	m3.max_budget_millions_usd = 950.0
	m3.max_mass_kg = 950.0
	m3.min_delta_v_ms = 7800.0
	m3.target_distance_au = 1.52
	m3.min_science_points = 195
	m3.radiation_level = 0.50
	m3.requires_edl_system = true
	m3.min_operational_instruments = 1
	m3.set_meta("is_frontier", false)
	missions.append(m3)
	
	# ==========================================================================
	# MISIONES 4–6: FRONTERA AVANZADA (DIFICULTAD EXTREMA)
	# ==========================================================================
	var m4 := MissionData.new()
	m4.tier = 4
	m4.mission_id = "m04_jovian_tides"
	m4.mission_name = "MISSION_4_NAME"
	m4.destination = "DEST_M4"
	m4.max_budget_millions_usd = 1900.0
	m4.max_mass_kg = 3335.0
	m4.min_delta_v_ms = 13000.0
	m4.target_distance_au = 5.2
	m4.min_science_points = 285
	m4.radiation_level = 1.00
	m4.forbids_solar_panels = true
	m4.requires_rtg = true
	m4.min_operational_instruments = 2
	m4.set_meta("is_frontier", true)
	missions.append(m4)
	
	var m5 := MissionData.new()
	m5.tier = 5
	m5.mission_id = "m05_neo_interceptor"
	m5.mission_name = "MISSION_5_NAME"
	m5.destination = "DEST_M5"
	m5.max_budget_millions_usd = 740.0
	m5.max_mass_kg = 1380.0
	m5.min_delta_v_ms = 5600.0
	m5.target_distance_au = 1.3
	m5.min_science_points = 255
	m5.radiation_level = 0.45
	m5.requires_ion_propulsion = true
	m5.min_operational_instruments = 1
	m5.set_meta("is_frontier", true)
	missions.append(m5)
	
	var m6 := MissionData.new()
	m6.tier = 6
	m6.mission_id = "m06_heliopause_explorer"
	m6.mission_name = "MISSION_6_NAME"
	m6.destination = "DEST_M6"
	m6.max_budget_millions_usd = 2650.0
	m6.max_mass_kg = 880.0
	m6.min_delta_v_ms = 16200.0
	m6.target_distance_au = 250.0
	m6.min_science_points = 390
	m6.radiation_level = 1.00
	m6.forbids_solar_panels = true
	m6.requires_rtg = true
	m6.min_operational_instruments = 3
	m6.set_meta("is_frontier", true)
	missions.append(m6)
	
	return missions
