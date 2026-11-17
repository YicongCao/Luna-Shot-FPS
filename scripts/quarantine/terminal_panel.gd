extends Control
# A single device-owned information surface. Counts, one primary action, no slogan.
var mission: Node3D
var can_interact: bool = false
var font: Font
const ICONS = preload("res://scripts/quarantine/pictograms.gd")
const INK = Color(.82,.94,.96)
const CYAN = Color(.30,.83,.92)
const AMBER = Color(1,.62,.25)

func _ready() -> void:
	font=ThemeDB.fallback_font
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void: queue_redraw()
func text_at(at: Vector2, value: String, size_px: int, tint: Color = INK) -> void:
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,tint)
func icon(kind: String, at: Vector2, extent: float, tint: Color) -> void:
	draw_texture_rect(ICONS.texture_for(kind),Rect2(at,Vector2.ONE*extent),false,tint)
func _draw() -> void:
	if font==null or not is_instance_valid(mission): return
	draw_rect(Rect2(0,0,640,384),Color(.015,.055,.075,.92))
	draw_rect(Rect2(2,2,636,380),Color(CYAN,.60),false,2)
	# Corner registration marks make the projected plane readable without a title bar.
	for x in [0,640]:
		for y in [0,384]:
			var at: Vector2=Vector2(x,y)
			draw_line(at,at+Vector2(24 if x==0 else -24,0),CYAN,4)
			draw_line(at,at+Vector2(0,24 if y==0 else -24),CYAN,4)
	if mission.stage==0:
		icon("bug",Vector2(42,52),90,AMBER)
		text_at(Vector2(164,86),"清除害虫",36)
		text_at(Vector2(164,180),"%d / %d"%[mission.kills,mission.total_bugs],72)
		icon("lock",Vector2(526,60),48,AMBER)
	elif mission.stage==1:
		icon("power",Vector2(42,52),90,CYAN)
		text_at(Vector2(164,86),"接通电源",36)
		text_at(Vector2(164,180),"0 / 1",72)
		if can_interact:
			var remaining: float=(1-mission.progress)*3.0
			draw_rect(Rect2(164,230,400,82),Color(CYAN,.10))
			draw_rect(Rect2(179,245,52,52),CYAN,false,2)
			text_at(Vector2(193,283),"E",32)
			text_at(Vector2(251,283),"按住  %.1f s"%remaining,32)
			# Time feedback is a fill, never a percentage or a second item counter.
			draw_line(Vector2(164,328),Vector2(564,328),Color(CYAN,.2),5)
			if mission.progress>0:
				draw_line(Vector2(164,328),Vector2(164+400*mission.progress,328),CYAN,5)
		else:
			text_at(Vector2(164,280),"靠近并看向面板",30)
	else:
		icon("exit",Vector2(42,52),90,CYAN)
		text_at(Vector2(164,86),"前往撤离点",36)
		var distance: float=mission.player.global_position.distance_to(mission.get_node("World/Markers/Extraction").global_position)
		text_at(Vector2(164,180),"%.0f m"%distance,72)
		icon("check",Vector2(526,60),48,CYAN)
