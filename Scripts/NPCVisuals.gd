class_name NPCVisuals
extends Node

# Nodos visuales independientes
var _char_base_body: TextureRect
var _char_face: TextureRect
var _char_iris: TextureRect
var _char_hair: TextureRect
var _char_clothing: TextureRect
var _director_sprite: TextureRect

const SKIN_COLORS := [
	Color("#ffdbac"), Color("#f5d0b1"), Color("#e8b996"), 
	Color("#d19c74"), Color("#b87e50"), Color("#966037"), 
	Color("#70421f"), Color("#543118"), Color("#3b220f")
]

const HAIR_COLORS := [
	Color("#fef08a"), Color("#fde047"), Color("#ca8a04"), 
	Color("#ea580c"), Color("#b91c1c"), Color("#713f12"), 
	Color("#57534e"), Color("#292524"), Color("#3f2c1d"), 
	Color("#1c1917"), Color("#09090b")
]

const EYE_COLORS := [
	Color("#284e32"), Color("#634120"), Color("#3b2219"), 
	Color("#20466b"), Color("#5b7083"), Color("#7d6138")
]

const CLOTHING_COLORS := [
	Color("#f8fafc"), Color("#94a3b8"), Color("#1e3a8a"), 
	Color("#c2410c"), Color("#15803d"), Color("#b45309"), Color("#334155")
]

var female_hairs: Array[Texture2D] = []

# Variable de caché para bloquear cambios de color al interactuar con botones
var cached_npc_id: String = ""

func prepare_mission_client(npc_id: String) -> void:
	_set_director_visible(false)
	_set_client_visible(true)
	
	# Si ya estamos mostrando a este NPC, no volvemos a generar colores aleatorios
	if cached_npc_id == npc_id:
		return
	cached_npc_id = npc_id
	
	var seed_val := npc_id.hash()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	
	var skin: Color = SKIN_COLORS[rng.randi() % SKIN_COLORS.size()]
	
	var hair: Color = skin
	for i in range(20):
		hair = HAIR_COLORS[rng.randi() % HAIR_COLORS.size()]
		if abs(skin.get_luminance() - hair.get_luminance()) > 0.22:
			break
			
	var iris: Color = EYE_COLORS[rng.randi() % EYE_COLORS.size()]
	var cloth: Color = CLOTHING_COLORS[rng.randi() % CLOTHING_COLORS.size()]
	
	if _char_base_body:
		_char_base_body.self_modulate = skin
		
	if _char_face:
		_char_face.self_modulate = Color.WHITE
		
	if _char_iris:
		_char_iris.self_modulate = iris
		
	if _char_hair:
		_char_hair.self_modulate = hair
		if not female_hairs.is_empty():
			_char_hair.texture = female_hairs[rng.randi() % female_hairs.size()]
			
	if _char_clothing:
		_char_clothing.self_modulate = cloth

func show_director(_mood: String, _animate_portrait: bool = true) -> void:
	cached_npc_id = "" # Limpia la caché al salir del cliente para permitir recalcular cuando regrese
	_set_client_visible(false)
	_set_director_visible(true)
	
	if _director_sprite:
		_director_sprite.self_modulate = Color.WHITE

func _set_client_visible(is_visible: bool) -> void:
	if _char_base_body: _char_base_body.visible = is_visible
	if _char_face: _char_face.visible = is_visible
	if _char_iris: _char_iris.visible = is_visible
	if _char_hair: _char_hair.visible = is_visible
	if _char_clothing: _char_clothing.visible = is_visible

func _set_director_visible(is_visible: bool) -> void:
	if _director_sprite:
		_director_sprite.visible = is_visible
