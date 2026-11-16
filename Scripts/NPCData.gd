class_name NPCData
extends Resource

@export_group("Identidad")
@export var npc_id: String = ""
@export var npc_name: String = ""
@export var role: String = ""
@export var faction: String = ""
@export var assigned_mission_id: String = "" # Vacío ("") para supervisora global
@export var assigned_tier: int = 0 # 0 = Global, 1..6 = Misión específica

@export_group("Reputación")
@export_range(0, 100) var reputation_current: int = 50
@export var reputation_initial: int = 50
@export var threshold_bonus: int = 75

@export_group("Retratos y Reacciones")
## Mapea mood ("neutral", "impressed", "skeptical", "alarmed", "celebrating") -> ruta de textura
@export var portraits: Dictionary = {}
## Lista de barks reactivos en el hangar
@export var hangar_barks: Array[Dictionary] = []
## Árbol de diálogo condicional: {"entry_node_id": String, "nodes": Array[Dictionary]}
@export var dialogue_tree: Dictionary = {}

# Estado en tiempo de ejecución
var bark_cooldowns: Dictionary = {}
var unlocked_hints: Array[String] = []
var negotiated_flags: Array[String] = []

func get_portrait_texture(mood: String) -> Texture2D:
	var path: String = portraits.get(mood, portraits.get("neutral", "res://IMG/112x112.png"))
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if ResourceLoader.exists("res://IMG/112x112.png"):
		return load("res://IMG/112x112.png") as Texture2D
	return null
