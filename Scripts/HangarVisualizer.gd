class_name HangarVisualizer
extends Control

@export var company_logos: Array[Texture2D] = []

var current_tier: int = 1
var active_logo_index: int = 0

# Variables de estado del hardware equipado
var has_power: bool = false
var power_id: String = ""

var has_propulsion: bool = false
var prop_id: String = ""

var has_defense: bool = false
var defense_id: String = ""

var has_avionics: bool = false
var instrument_count: int = 0
var scan_line_y: float = 0.0

# Las 4 agencias espaciales oficiales
const FACTION_PALETTES := [
	{"primary": Color("#38bdf8"), "secondary": Color("#0284c7"), "name": "CONAE (Argentina)"},
	{"primary": Color("#facc15"), "secondary": Color("#ca8a04"), "name": "Canadian Space Agency"},
	{"primary": Color("#f97316"), "secondary": Color("#c2410c"), "name": "European Space Agency"},
	{"primary": Color("#a855f7"), "secondary": Color("#7e22ce"), "name": "Spanish Space Agency"}
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	scan_line_y = fmod(scan_line_y + delta * 45.0, maxf(size.y, 1.0))
	queue_redraw()

func update_ship(tier: int, instruments: Dictionary, slots: Dictionary) -> void:
	current_tier = clampi(tier, 1, 6)
	active_logo_index = (current_tier - 1) % 4
	instrument_count = instruments.size()
	
	has_power = slots.has("power")
	power_id = str(slots["power"].get("id", "")) if has_power else ""
	
	has_propulsion = slots.has("propulsion")
	prop_id = str(slots["propulsion"].get("id", "")) if has_propulsion else ""
	
	has_defense = slots.has("defense")
	defense_id = str(slots["defense"].get("id", "")) if has_defense else ""
	
	has_avionics = slots.has("avionics")
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	
	var pal: Dictionary = FACTION_PALETTES[active_logo_index]
	var accent: Color = pal["primary"]
	
	# 1. FONDO DE HANGAR ORBITAL
	draw_rect(Rect2(0, 0, w, h), Color("#070d19"), true)
	draw_rect(Rect2(0, h * 0.55, w, h * 0.45), Color("#0b1528"), true)
	
	var grid_col := Color(accent.r, accent.g, accent.b, 0.08)
	var step := 48.0
	for x in range(0, int(w), int(step)):
		draw_line(Vector2(x, 0), Vector2(x, h), grid_col, 1.0)
	for y in range(0, int(h), int(step)):
		draw_line(Vector2(0, y), Vector2(w, y), grid_col, 1.0)
	
	draw_line(Vector2(0, scan_line_y), Vector2(w, scan_line_y), Color(accent.r, accent.g, accent.b, 0.14), 2.0)
	
	# 2. LOS 4 LOGOS SUPERIORES (¡Mucho más grandes y destacados!)
	var start_x := w * 0.26
	var end_x := w * 0.74
	var logo_y := h * 0.14
	var circle_radius := 50.0
	
	for idx in range(4):
		var t_pos := float(idx) / 3.0
		var l_pos := Vector2(lerpf(start_x, end_x, t_pos), logo_y)
		var is_active := (idx == active_logo_index)
		var l_col := accent if is_active else Color(0.5, 0.6, 0.75, 0.35)
		
		draw_arc(l_pos, circle_radius, 0, TAU, 40, l_col, 3.5 if is_active else 1.5)
		if is_active:
			draw_circle(l_pos, circle_radius - 2.0, Color(accent.r, accent.g, accent.b, 0.18))
		
		if idx < company_logos.size() and company_logos[idx] != null:
			var tex := company_logos[idx]
			var tint := Color.WHITE if is_active else Color(0.8, 0.85, 0.95, 0.5)
			_draw_texture_aspect_fit(tex, l_pos, 82.0, tint)
		else:
			_draw_agency_logo(idx, l_pos, 30.0, l_col)
	
	# 3. POSICIÓN DE ENSAMBLAJE DE LA NAVE
	var cx := w * 0.50
	var cy := h * 0.25
	
	# Soporte / Grúa del hangar
	draw_line(Vector2(cx - 135, cy - 60), Vector2(cx - 55, cy - 20), Color("#1e293b"), 4.0)
	draw_line(Vector2(cx + 135, cy - 60), Vector2(cx + 55, cy - 20), Color("#1e293b"), 4.0)
	draw_arc(Vector2(cx, cy), 90.0, 0, TAU, 48, Color(accent.r, accent.g, accent.b, 0.22), 1.5)
	
	# ==========================================================================
	# DIBUJO DE PROPULSIÓN
	# ==========================================================================
	if has_propulsion:
		if prop_id.contains("ion"):
			var ion_pts := PackedVector2Array([
				Vector2(cx - 16, cy + 36), Vector2(cx + 16, cy + 36),
				Vector2(cx + 22, cy + 58), Vector2(cx - 22, cy + 58)
			])
			draw_colored_polygon(ion_pts, Color("#0284c7"))
			draw_polyline(ion_pts, Color("#38bdf8"), 2.0)
			draw_circle(Vector2(cx, cy + 62), 13.0, Color(0, 0.8, 1, 0.5))
			draw_circle(Vector2(cx, cy + 62), 6.0, Color("#7dd3fc"))
		elif prop_id.contains("heavy") or prop_id.contains("tli") or prop_id.contains("prop"):
			var heavy_pts := PackedVector2Array([
				Vector2(cx - 24, cy + 36), Vector2(cx + 24, cy + 36),
				Vector2(cx + 36, cy + 68), Vector2(cx - 36, cy + 68)
			])
			draw_colored_polygon(heavy_pts, Color("#334155"))
			draw_polyline(heavy_pts, Color("#f59e0b"), 2.0)
			draw_circle(Vector2(cx, cy + 73), 15.0, Color(1, 0.5, 0, 0.5))
			draw_circle(Vector2(cx, cy + 71), 8.0, Color("#fbbf24"))
		else:
			var std_pts := PackedVector2Array([
				Vector2(cx - 16, cy + 36), Vector2(cx + 16, cy + 36),
				Vector2(cx + 24, cy + 54), Vector2(cx - 24, cy + 54)
			])
			draw_colored_polygon(std_pts, Color("#475569"))
			draw_circle(Vector2(cx, cy + 58), 10.0, Color("#f97316"))

	# ==========================================================================
	# DIBUJO DE ENERGÍA
	# ==========================================================================
	if has_power:
		if power_id.contains("rtg"):
			draw_rect(Rect2(cx - 65, cy - 10, 32, 26), Color("#c2410c"), true)
			draw_rect(Rect2(cx + 33, cy - 10, 32, 26), Color("#c2410c"), true)
			draw_rect(Rect2(cx - 65, cy - 10, 32, 26), Color("#fb923c"), false, 2.0)
			draw_rect(Rect2(cx + 33, cy - 10, 32, 26), Color("#fb923c"), false, 2.0)
			draw_circle(Vector2(cx - 49, cy + 3), 4.5, Color("#fef08a"))
			draw_circle(Vector2(cx + 49, cy + 3), 4.5, Color("#fef08a"))
		elif power_id.contains("pro") or power_id.contains("bat") or power_id.contains("solar_pro"):
			draw_rect(Rect2(cx - 145, cy - 16, 110, 32), Color("#1e3a8a"), true)
			draw_rect(Rect2(cx + 35, cy - 16, 110, 32), Color("#1e3a8a"), true)
			draw_rect(Rect2(cx - 145, cy - 16, 110, 32), Color("#60a5fa"), false, 2.0)
			draw_rect(Rect2(cx + 35, cy - 16, 110, 32), Color("#60a5fa"), false, 2.0)
			for gx in [-115, -85, -55, 55, 85, 115]:
				draw_line(Vector2(cx + gx, cy - 16), Vector2(cx + gx, cy + 16), Color("#93c5fd"), 1.0)
		else:
			draw_rect(Rect2(cx - 115, cy - 12, 80, 24), Color("#1d4ed8"), true)
			draw_rect(Rect2(cx + 35, cy - 12, 80, 24), Color("#1d4ed8"), true)
			draw_rect(Rect2(cx - 115, cy - 12, 80, 24), Color("#93c5fd"), false, 1.5)
			draw_rect(Rect2(cx + 35, cy - 12, 80, 24), Color("#93c5fd"), false, 1.5)

	# ==========================================================================
	# CHASIS / FUSELAJE PRINCIPAL
	# ==========================================================================
	_draw_mission_chassis(cx, cy, accent)

	# Sello de la agencia en el centro del fuselaje (Bien visible y nítido a 54px)
	if active_logo_index < company_logos.size() and company_logos[active_logo_index] != null:
		var ship_tex := company_logos[active_logo_index]
		_draw_texture_aspect_fit(ship_tex, Vector2(cx, cy), 54.0, Color.WHITE)
	else:
		_draw_agency_logo(active_logo_index, Vector2(cx, cy), 22.0, accent)

	# ==========================================================================
	# INSTRUMENTOS CIENTÍFICOS
	# ==========================================================================
	var inst_offsets := [
		Vector2(-42, -26), Vector2(42, -26),
		Vector2(-42, 24), Vector2(42, 24)
	]
	for k in range(mini(instrument_count, 4)):
		var ipos: Vector2 = Vector2(cx, cy) + inst_offsets[k]
		draw_circle(ipos, 8.5, Color("#10b981"))
		draw_arc(ipos, 8.5, 0, TAU, 16, Color("#a7f3d0"), 1.5)

	# ==========================================================================
	# BLINDAJE / COMMS / EDL
	# ==========================================================================
	if has_defense:
		if defense_id.contains("comm"):
			draw_arc(Vector2(cx, cy - 52), 26.0, PI * 0.15, PI * 0.85, 24, Color("#f8fafc"), 3.0)
			draw_line(Vector2(cx, cy - 36), Vector2(cx, cy - 58), Color("#94a3b8"), 2.0)
			draw_circle(Vector2(cx, cy - 60), 4.0, accent)
		elif defense_id.contains("hi") or defense_id.contains("shield"):
			var heavy_shield := PackedVector2Array([
				Vector2(cx - 42, cy - 36), Vector2(cx + 42, cy - 36),
				Vector2(cx + 28, cy - 66), Vector2(cx - 28, cy - 66)
			])
			draw_colored_polygon(heavy_shield, Color("#eab308"))
			draw_polyline(heavy_shield, Color("#fef08a"), 2.5)
		else:
			var std_shield := PackedVector2Array([
				Vector2(cx - 38, cy - 36), Vector2(cx + 38, cy - 36),
				Vector2(cx, cy - 64)
			])
			draw_colored_polygon(std_shield, Color("#eab308"))
			draw_polyline(std_shield, Color("#fef08a"), 2.0)

	# ==========================================================================
	# AVIÓNICA / LIDAR
	# ==========================================================================
	if has_avionics:
		draw_circle(Vector2(cx, cy - 42), 6.0, Color("#22c55e"))
		draw_arc(Vector2(cx, cy - 42), 11.0, -PI * 0.8, -PI * 0.2, 16, Color("#4ade80"), 1.5)

# ==============================================================================
# FUNCIÓN AUXILIAR: Mantiene la proporción exacta sin distorsionar nunca
# ==============================================================================
func _draw_texture_aspect_fit(tex: Texture2D, center: Vector2, max_size: float, modulate: Color) -> void:
	var sz := tex.get_size()
	if sz.x <= 0 or sz.y <= 0:
		return
	var scale_factor := minf(max_size / sz.x, max_size / sz.y)
	var draw_size := sz * scale_factor
	var dest_rect := Rect2(center - draw_size * 0.5, draw_size)
	draw_texture_rect(tex, dest_rect, false, modulate)

# ==============================================================================
# CHASIS DISTINTIVOS POR CADA UNA DE LAS 6 MISIONES
# ==============================================================================
func _draw_mission_chassis(cx: float, cy: float, accent: Color) -> void:
	match current_tier:
		1:
			var rect := Rect2(cx - 30, cy - 32, 60, 64)
			draw_rect(rect, Color("#cbd5e1"), true)
			draw_rect(Rect2(cx - 24, cy - 26, 48, 52), Color("#1e293b"), true)
			draw_rect(rect, accent, false, 2.0)
			draw_line(Vector2(cx - 18, cy - 32), Vector2(cx - 18, cy + 32), accent, 1.5)
			draw_line(Vector2(cx + 18, cy - 32), Vector2(cx + 18, cy + 32), accent, 1.5)
		2:
			var oct := PackedVector2Array([
				Vector2(cx - 22, cy - 36), Vector2(cx + 22, cy - 36),
				Vector2(cx + 34, cy - 12), Vector2(cx + 34, cy + 16),
				Vector2(cx + 22, cy + 36), Vector2(cx - 22, cy + 36),
				Vector2(cx - 34, cy + 16), Vector2(cx - 34, cy - 12)
			])
			draw_colored_polygon(oct, Color("#94a3b8"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - 18, cy - 30), Vector2(cx + 18, cy - 30),
				Vector2(cx + 28, cy + 28), Vector2(cx - 28, cy + 28)
			]), Color("#0f172a"))
			draw_polyline(oct, accent, 2.5)
		3:
			var aero := PackedVector2Array([
				Vector2(cx - 16, cy - 42), Vector2(cx + 16, cy - 42),
				Vector2(cx + 38, cy + 28), Vector2(cx - 38, cy + 28)
			])
			draw_colored_polygon(aero, Color("#b45309"))
			draw_polyline(aero, Color("#fde68a"), 2.5)
			draw_line(Vector2(cx - 28, cy + 28), Vector2(cx - 44, cy + 42), Color("#cbd5e1"), 3.0)
			draw_line(Vector2(cx + 28, cy + 28), Vector2(cx + 44, cy + 42), Color("#cbd5e1"), 3.0)
		4:
			var core1 := Rect2(cx - 34, cy - 34, 30, 68)
			var core2 := Rect2(cx + 4, cy - 34, 30, 68)
			draw_rect(core1, Color("#475569"), true)
			draw_rect(core2, Color("#475569"), true)
			draw_rect(core1, accent, false, 2.0)
			draw_rect(core2, accent, false, 2.0)
			draw_line(Vector2(cx - 4, cy - 20), Vector2(cx + 4, cy - 20), Color("#facc15"), 3.0)
			draw_line(Vector2(cx - 4, cy + 20), Vector2(cx + 4, cy + 20), Color("#facc15"), 3.0)
		5:
			var dart := PackedVector2Array([
				Vector2(cx, cy - 48),
				Vector2(cx + 32, cy + 20),
				Vector2(cx + 16, cy + 40),
				Vector2(cx - 16, cy + 40),
				Vector2(cx - 32, cy + 20)
			])
			draw_colored_polygon(dart, Color("#334155"))
			draw_polyline(dart, accent, 2.5)
			draw_line(Vector2(cx, cy - 48), Vector2(cx, cy + 30), Color("#38bdf8"), 2.0)
		_:
			var cyl := Rect2(cx - 22, cy - 40, 44, 80)
			draw_rect(cyl, Color("#64748b"), true)
			draw_rect(Rect2(cx - 16, cy - 34, 32, 68), Color("#0f172a"), true)
			draw_rect(cyl, accent, false, 2.5)
			draw_line(Vector2(cx - 22, cy - 20), Vector2(cx - 52, cy - 30), Color("#e2e8f0"), 2.0)
			draw_line(Vector2(cx + 22, cy - 20), Vector2(cx + 52, cy - 30), Color("#e2e8f0"), 2.0)

func _draw_agency_logo(logo_id: int, center: Vector2, r: float, col: Color) -> void:
	match logo_id % 4:
		0:
			draw_circle(center, r * 0.35, col)
			for i in range(8):
				var ang := float(i) * TAU / 8.0
				draw_line(center + Vector2(cos(ang), sin(ang)) * r * 0.5, center + Vector2(cos(ang), sin(ang)) * r * 0.9, col, 1.5)
		1:
			draw_arc(center, r * 0.7, -PI * 0.7, PI * 0.7, 24, col, 2.5)
			draw_circle(center + Vector2(r * 0.3, 0), r * 0.25, col)
		2:
			draw_circle(center, r * 0.4, col)
			draw_arc(center, r * 0.85, -0.5, PI + 0.5, 20, col, 2.0)
		3:
			draw_line(center - Vector2(r * 0.7, 0), center + Vector2(r * 0.8, 0), col, 2.5)
			draw_line(center - Vector2(0, r * 0.7), center + Vector2(0, r * 0.8), col, 2.5)
			draw_circle(center, r * 0.25, col)
