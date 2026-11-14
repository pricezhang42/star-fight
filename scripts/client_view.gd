extends Node2D
## The joining computer in a LAN game (red ship). Runs no game logic: it draws
## what the host streams (see NetMirror) and sends its keys and mouse to the
## host.

const KENVECTOR := preload("res://assets/kenney_space_shooter_redux/fonts/kenvector_future.ttf")
const COMET_SCENE := preload("res://scenes/comet.tscn")

var _textures := {} # id -> Texture2D
var _sprites := {} # instance id -> Sprite2D
var _labels := {} # instance id -> Label
var _lines := {} # instance id -> Line2D
var _parts := {} # instance id -> CPUParticles2D
var _shaders := {} # path -> Shader
var _draws: Array = []
var _view_center := Vector2.ZERO
var _view_size := Vector2(2600, 1600)
var _got_world := false
var _trail_template: CPUParticles2D

@onready var world: Node2D = $World
@onready var draws_node: Node2D = $World/Draws
@onready var camera: Camera2D = $Camera2D
@onready var background: Sprite2D = $Background
@onready var bars: Control = $Letterbox/Bars
@onready var waiting: Label = $Letterbox/Waiting


func _ready() -> void:
	draws_node.draw.connect(_on_draws_draw)
	var comet := COMET_SCENE.instantiate()
	_trail_template = comet.get_node("Trail").duplicate()
	comet.free()


func _process(_delta: float) -> void:
	# Fit the host's view into this window, with black bars if the shapes differ.
	var win := get_viewport().get_visible_rect().size
	var z := minf(win.x / _view_size.x, win.y / _view_size.y)
	camera.zoom = Vector2(z, z)
	camera.global_position = _view_center
	var shown := _view_size * z
	var pad := (win - shown) / 2.0
	var top: ColorRect = bars.get_node("Top")
	var bottom: ColorRect = bars.get_node("Bottom")
	var left: ColorRect = bars.get_node("Left")
	var right: ColorRect = bars.get_node("Right")
	top.position = Vector2.ZERO
	top.size = Vector2(win.x, pad.y)
	bottom.position = Vector2(0, win.y - pad.y)
	bottom.size = Vector2(win.x, pad.y)
	left.position = Vector2.ZERO
	left.size = Vector2(pad.x, win.y)
	right.position = Vector2(win.x - pad.x, 0)
	right.size = Vector2(pad.x, win.y)
	waiting.visible = not _got_world
	# Same tiled background as the host.
	var tile := float(background.texture.get_height())
	background.position = Vector2(-700, floorf((_view_center.y - 2100.0) / tile) * tile)

	# The red ship's controls go to the host.
	var mouse := get_global_mouse_position()
	var buttons := 0
	if Input.is_action_pressed("thrust"):
		buttons |= Net.BTN_THRUST
	if Input.is_action_pressed("brake"):
		buttons |= Net.BTN_BRAKE
	if Input.is_action_pressed("fire"):
		buttons |= Net.BTN_FIRE
	Net.send_input(Input.get_axis("turn_left", "turn_right"), buttons, mouse)
	for action in ["dash", "restart"]:
		if Input.is_action_just_pressed(action):
			Net.send_event(action, mouse)


func add_textures(entries: Array) -> void:
	for e in entries:
		var key: String = e[1]
		var tex: Texture2D = null
		if key.begins_with("grad:"):
			tex = _gradient_disc(Color.html(key.trim_prefix("grad:")))
		else:
			tex = load(key) as Texture2D
		_textures[e[0]] = tex


## Same soft disc the flash bang uses on the host.
func _gradient_disc(color: Color) -> Texture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	grad.colors = PackedColorArray([color, color, Color(color, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


func apply_world(packet: PackedByteArray) -> void:
	_got_world = true
	var b := StreamPeerBuffer.new()
	b.data_array = packet
	_view_center = Vector2(b.get_float(), b.get_float())
	_view_size = Vector2(b.get_float(), b.get_float())

	# Sprites
	var seen := {}
	var order := 0
	for i in b.get_u16():
		var id := b.get_64()
		var tid := b.get_u16()
		var t := Transform2D(Vector2(b.get_float(), b.get_float()), Vector2(b.get_float(), b.get_float()), Vector2(b.get_float(), b.get_float()))
		var off := Vector2(b.get_float(), b.get_float())
		var col := Color.hex(b.get_u32())
		var z := b.get_16()
		var shader_info = b.get_var() if b.get_u8() == 1 else null
		seen[id] = true
		var s: Sprite2D = _sprites.get(id)
		if s == null:
			s = Sprite2D.new()
			world.add_child(s)
			_sprites[id] = s
		s.texture = _textures.get(tid)
		s.transform = t
		s.offset = off
		s.modulate = col
		s.z_index = z
		if shader_info != null:
			var mat := s.material as ShaderMaterial
			if mat == null:
				mat = ShaderMaterial.new()
				if not _shaders.has(shader_info[0]):
					_shaders[shader_info[0]] = load(shader_info[0])
				mat.shader = _shaders[shader_info[0]]
				s.material = mat
			for k in shader_info[1]:
				mat.set_shader_parameter(k, shader_info[1][k])
		world.move_child(s, order)
		order += 1
	_prune(_sprites, seen)

	# Labels
	seen = {}
	for i in b.get_u16():
		var id := b.get_64()
		var text := b.get_utf8_string()
		var pos := Vector2(b.get_float(), b.get_float())
		var scl := Vector2(b.get_float(), b.get_float())
		var size := Vector2(b.get_float(), b.get_float())
		var font_size := b.get_u16()
		var font_color := Color.hex(b.get_u32())
		var outline := b.get_u8()
		var align := b.get_u8()
		var col := Color.hex(b.get_u32())
		var z := b.get_16()
		seen[id] = true
		var l: Label = _labels.get(id)
		if l == null:
			l = Label.new()
			l.label_settings = LabelSettings.new()
			l.label_settings.font = KENVECTOR
			l.label_settings.outline_color = Color.BLACK
			world.add_child(l)
			_labels[id] = l
		l.text = text
		l.position = pos
		l.scale = scl
		l.size = size
		l.label_settings.font_size = font_size
		l.label_settings.font_color = font_color
		l.label_settings.outline_size = outline
		l.horizontal_alignment = align
		l.modulate = col
		l.z_index = z
	_prune(_labels, seen)

	# Lines
	seen = {}
	for i in b.get_u16():
		var id := b.get_64()
		var pts: PackedVector2Array = b.get_var()
		var width := b.get_float()
		var col := Color.hex(b.get_u32())
		var z := b.get_16()
		seen[id] = true
		var ln: Line2D = _lines.get(id)
		if ln == null:
			ln = Line2D.new()
			world.add_child(ln)
			_lines[id] = ln
		ln.points = pts
		ln.width = width
		ln.default_color = col
		ln.z_index = z
	_prune(_lines, seen)

	# Comet trails
	seen = {}
	for i in b.get_u16():
		var id := b.get_64()
		var pos := Vector2(b.get_float(), b.get_float())
		var dir := Vector2(b.get_float(), b.get_float())
		b.get_u8() # trail kind (unused: there is only one kind of comet now)
		seen[id] = true
		var p: CPUParticles2D = _parts.get(id)
		if p == null:
			p = _trail_template.duplicate()
			world.add_child(p)
			_parts[id] = p
		p.global_position = pos
		p.direction = dir
		p.emitting = true
	for id in _parts.keys():
		if not seen.has(id):
			# Let the trail fade out instead of vanishing.
			var p: CPUParticles2D = _parts[id]
			p.emitting = false
			get_tree().create_timer(0.8).timeout.connect(p.queue_free)
			_parts.erase(id)

	_draws = b.get_var()
	draws_node.queue_redraw()


func _prune(pool: Dictionary, seen: Dictionary) -> void:
	for id in pool.keys():
		if not seen.has(id):
			pool[id].queue_free()
			pool.erase(id)


## Custom-drawn things from the host: [kind, ..., z]
func _on_draws_draw() -> void:
	for cmd in _draws:
		match cmd[0]:
			"line":
				draws_node.draw_line(cmd[1], cmd[2], cmd[3], cmd[4])
			"arc":
				draws_node.draw_arc(cmd[1], cmd[2], cmd[3], cmd[4], 96, cmd[5], cmd[6])
