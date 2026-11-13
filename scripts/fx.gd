class_name Fx
## Small helpers for one-shot visual and sound effects.


## Spawn a sprite that pops and fades out at `pos`.
static func flash(parent: Node, pos: Vector2, tex: Texture2D, size := 1.0, time := 0.25) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.scale = Vector2.ONE * size * 0.5
	s.rotation = randf() * TAU
	parent.add_child(s)
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "scale", Vector2.ONE * size * 1.4, time)
	tw.tween_property(s, "modulate:a", 0.0, time)
	tw.chain().tween_callback(s.queue_free)


## Play a sound that outlives the node that triggered it.
static func sound(parent: Node, stream: AudioStream, volume_db := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
