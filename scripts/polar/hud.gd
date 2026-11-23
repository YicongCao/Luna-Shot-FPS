extends Control
const Signs = preload("res://scripts/polar/signs.gd")
const INK := Color(.88,.93,.96)
const SHEET := Color(.025,.04,.055,.81)
const ACTIVE := Color(.63,.87,1)
const ALERT := Color(.98,.45,.22)

var health := 100
var record := false
var cargo_state := 0
var action_text := ""
var objective := ""
var hold := 0.0
var reloading := false
var aim := false
var tag := 0.0
var signal_dir := 0.0
var signal_age := 0.0
var reserve := 18
var sealed := false
var panel: PanelContainer
var title: Label
var result: Label
var controls: Label
var resume_button: Button
var face: Font

signal resume_requested
signal restart_requested
signal quit_requested

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	face = ThemeDB.fallback_font
	_build_menu()

func _build_menu() -> void:
	panel = PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	panel.offset_left = -238
	panel.offset_right = 238
	panel.offset_top = -138
	panel.offset_bottom = 138
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.023,.038,.050,.96)
	style.set_border_width_all(1)
	style.border_color = Color(.37,.50,.58,.87)
	style.set_corner_radius_all(7)
	style.content_margin_left = 27
	style.content_margin_right = 27
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel",style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",10)
	panel.add_child(stack)
	title = Label.new()
	title.add_theme_font_size_override("font_size",30)
	stack.add_child(title)
	result = Label.new()
	result.add_theme_font_size_override("font_size",20)
	stack.add_child(result)
	controls = Label.new()
	controls.text = "WASD 移动  /  Shift 冲刺  /  空格 跳跃\n左键 脉冲  /  右键 瞄准  /  R 换弹  /  E 交互"
	controls.add_theme_font_size_override("font_size",17)
	stack.add_child(controls)
	resume_button = _button(stack,"继续",resume_requested.emit)
	_button(stack,"重开  F5",restart_requested.emit)
	_button(stack,"退出",quit_requested.emit)
	panel.hide()

func _button(root: Control, label: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size.y = 42
	b.pressed.connect(callback)
	root.add_child(b)
	return b

func menu(which: String) -> void:
	panel.visible = not which.is_empty()
	if not panel.visible: return
	var paused := which == "pause"
	title.text = "暂停" if paused else ("撤离完成" if which == "complete" else "生命支持中断")
	controls.visible = paused
	resume_button.visible = paused
	result.visible = not paused
	result.text = "记录匣 %d/1     冰芯 %d/1" % [int(record),int(cargo_state==4)]
	if paused: resume_button.grab_focus()

func _draw() -> void:
	if panel == null or panel.visible: return
	var dims := size
	var center := dims*.5
	if not sealed:
		draw_rect(Rect2(26,24,184,72),SHEET)
		draw_string(face,Vector2(36,49),objective,HORIZONTAL_ALIGNMENT_LEFT,-1,19,INK)
		count("record",Vector2(35,62),record,ACTIVE if record else INK)
		count("ice",Vector2(114,62),cargo_state==4,ACTIVE if cargo_state > 0 else INK)
		if cargo_state > 0 and cargo_state < 4:
			draw_rect(Rect2(116,88,61,2),Color(.38,.69,.81,.9))
		draw_rect(Rect2(26,dims.y-60,146,34),SHEET)
		draw_texture_rect(Signs.icon("suit"),Rect2(32,dims.y-55,24,24),false,INK)
		draw_rect(Rect2(64,dims.y-45,95,4),Color(.27,.34,.39))
		draw_rect(Rect2(64,dims.y-45,95*float(health)/100.0,4),ALERT if health < 36 else ACTIVE)
		if reloading:
			draw_string(face,Vector2(dims.x-132,dims.y-38),"换弹",HORIZONTAL_ALIGNMENT_RIGHT,106,20,INK)
		elif reserve < 6:
			draw_string(face,Vector2(dims.x-132,dims.y-38),"+ %d" % reserve,HORIZONTAL_ALIGNMENT_RIGHT,106,20,INK)
		if not aim and tag == 0.0:
			draw_circle(center,1.7,Color(.02,.04,.06,.85))
			draw_circle(center,1.0,INK)
		elif tag == 0.0:
			draw_circle(center,1.45,Color(.73,.89,.99))
		if tag > 0.0:
			for i in 4:
				var axis := Vector2.from_angle(i*TAU/4.0+PI*.25)
				draw_line(center+axis*6.0,center+axis*12.5,ACTIVE,1.5,true)
		if signal_age > 0.0:
			var angle := signal_dir-PI*.5
			draw_arc(center,58,angle-.26,angle+.26,14,Color(ALERT,clampf(signal_age*2.4,0,.92)),2.0,true)
	if not action_text.is_empty():
		var text := "E   "+action_text
		var width := face.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x+32
		var box := Rect2(center.x-width*.5,center.y+68,width,36)
		draw_rect(box,SHEET)
		draw_string(face,box.position+Vector2(16,25),text,HORIZONTAL_ALIGNMENT_LEFT,-1,20,INK)
		if hold > 0.0:
			draw_rect(Rect2(box.position.x,box.end.y-2,box.size.x*hold,2),ACTIVE)

func count(which: String, at: Vector2, done: bool, color: Color) -> void:
	draw_texture_rect(Signs.icon(which),Rect2(at,Vector2(24,24)),false,color)
	draw_string(face,at+Vector2(25,20),"1/1" if done else "0/1",HORIZONTAL_ALIGNMENT_LEFT,-1,18,color)
