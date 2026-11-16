class_name MissionData
extends Resource

@export_group("Identificación")
@export var mission_id: String = ""
@export var mission_name: String = ""
@export_range(1, 6) var tier: int = 1
@export var destination: String = ""
@export_multiline var engineering_objective: String = ""

@export_group("Restricciones (Constraints)")
@export var max_budget_millions_usd: float = 150.0
@export var max_mass_kg: float = 500.0
@export var min_delta_v_ms: float = 3500.0
@export var target_distance_au: float = 1.0 # 1.0 AU = Órbita terrestre

@export_group("Metas Científicas (Scientific Goals)")
## Array de Diccionarios: [{"goal_id": "climate_ir", "weight": 0.5}]
@export var scientific_goals: Array[Dictionary] = []

@export_group("Peligros Ambientales (Environmental Hazards)")
@export_range(0.0, 1.0) var radiation_level: float = 0.1
@export var thermal_extremes: bool = false
@export var communication_latency_minutes: float = 0.0
@export var atmospheric_density_kg_m3: float = 0.0 # Para EDL o aerofrenado

@export_group("Criterios de Éxito y Reglas Especiales")
@export var min_science_points: int = 100
@export_range(0.0, 1.0) var safety_threshold: float = 0.8
@export var forbids_solar_panels: bool = false
@export var requires_rtg: bool = false
@export var requires_edl_system: bool = false
@export var requires_ion_propulsion: bool = false
@export var min_operational_instruments: int = 1
