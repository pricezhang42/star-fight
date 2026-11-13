extends Node2D
## Darth's Flash bang: a bright flash, then a dark soft-edged cloud that hides
## part of the map for a few seconds before fading away.

@export var radius := 460.0
@export var duration := 4.0
@export var fade_time := 0.6

var _t := 0.0
var _cloud: Sprite2D
var _flash: Sprite2D


func _ready() -> void:
	z_index = 50 # above the level, below the HUD
	_cloud = _make_disc(Color(0.02, 0.0, 0.05, 1.0))
	_flash = _make_disc(Color(1, 1, 1, 1))
	_flash.scale *= 0.6


## A round sprite that is solid in the middle and fades out at the edge
## (Godot's built-in radial gradient texture, no image file needed).
func _make_disc(color: Color) -> Sprite2D:
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
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2.ONE * (radius * 2.0 / 256.0)
	add_child(s)
	return s


func _process(delta: float) -> void:
	_t += delta
	# Quick white flash that blooms outwards.
	var f := clampf(_t / 0.35, 0.0, 1.0)
	_flash.modulate.a = 1.0 - f
	_flash.scale = Vector2.ONE * (radius * 2.0 / 256.0) * lerpf(0.6, 1.25, f)
	# Dark cloud: pops in, holds, fades out.
	var a := clampf(_t / 0.25, 0.0, 1.0)
	if _t > duration - fade_time:
		a = clampf((duration - _t) / fade_time, 0.0, 1.0)
	_cloud.modulate.a = a * 0.97
	if _t >= duration:
		queue_free()
