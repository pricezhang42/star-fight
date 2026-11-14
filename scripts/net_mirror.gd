class_name NetMirror
## Streams "what is drawn" from the host's game to the joining computer.
##
## The host walks its game scene every frame and packs every visible
## Sprite2D, world Label and Line2D (with its on-screen transform, colour and
## draw order), plus a few custom-drawn things (black hole rings, laser
## warnings) and comet trails. The joining computer rebuilds the same
## picture from that, without running any game logic itself.

const VIEW_MARGIN := 900.0 ## also send things just outside the view


class Sender:
	extends RefCounted
	var _tex_ids := {} # key -> int
	var _new_textures := [] # [[id, key], ...] not yet sent

	func take_new_textures() -> Array:
		var out := _new_textures
		_new_textures = []
		return out

	func _tex_id(tex: Texture2D) -> int:
		var key := tex.resource_path
		if tex is GradientTexture2D:
			var g: Gradient = (tex as GradientTexture2D).gradient
			key = "grad:" + g.colors[0].to_html()
		if key == "":
			return -1
		if not _tex_ids.has(key):
			_tex_ids[key] = _tex_ids.size()
			_new_textures.append([_tex_ids[key], key])
		return _tex_ids[key]

	func build(scene: Node, center: Vector2, view_size: Vector2) -> PackedByteArray:
		var view := Rect2(center - view_size / 2.0, view_size).grow(VIEW_MARGIN)
		var sprites := StreamPeerBuffer.new()
		var labels := StreamPeerBuffer.new()
		var lines := StreamPeerBuffer.new()
		var parts := StreamPeerBuffer.new()
		var n_sprites := 0
		var n_labels := 0
		var n_lines := 0
		var n_parts := 0
		var draws := []
		# Depth-first, in draw order. Each entry: [node, modulate, z]
		var stack := []
		var kids := scene.get_children()
		for i in range(kids.size() - 1, -1, -1):
			stack.append([kids[i], Color.WHITE, 0])
		while not stack.is_empty():
			var entry: Array = stack.pop_back()
			var node: Node = entry[0]
			var mod: Color = entry[1]
			var z: int = entry[2]
			if node is CanvasLayer or node.is_in_group("net_skip"):
				continue
			if node is CanvasItem:
				var ci := node as CanvasItem
				if not ci.visible:
					continue
				mod = mod * ci.modulate
				z = (z + ci.z_index) if ci.z_as_relative else ci.z_index
				var own := mod * ci.self_modulate
				if node is Sprite2D:
					var s := node as Sprite2D
					if s.texture and view.has_point(s.global_position):
						var tid := _tex_id(s.texture)
						if tid >= 0:
							n_sprites += 1
							_put_sprite(sprites, s, tid, own, z)
				elif node is Label:
					var l := node as Label
					if l.text != "" and view.has_point(l.global_position):
						n_labels += 1
						_put_label(labels, l, own, z)
				elif node is Line2D:
					var ln := node as Line2D
					if ln.points.size() >= 2:
						n_lines += 1
						lines.put_64(ln.get_instance_id())
						var pts := PackedVector2Array()
						for p in ln.points:
							pts.append(ln.to_global(p))
						lines.put_var(pts)
						lines.put_float(ln.width)
						lines.put_u32(own.to_rgba32())
						lines.put_16(z)
				elif node is CPUParticles2D and node.is_in_group("net_particles"):
					var cp := node as CPUParticles2D
					n_parts += 1
					parts.put_64(cp.get_instance_id())
					parts.put_float(cp.global_position.x)
					parts.put_float(cp.global_position.y)
					parts.put_float(cp.direction.x)
					parts.put_float(cp.direction.y)
					parts.put_u8(int(cp.get_meta("net_kind", 0)))
				if node.is_in_group("net_draw") and node.has_method("net_draw_commands"):
					for cmd in node.net_draw_commands():
						cmd.append(z)
						draws.append(cmd)
			var ch := node.get_children()
			for i in range(ch.size() - 1, -1, -1):
				stack.append([ch[i], mod, z])
		var out := StreamPeerBuffer.new()
		out.put_float(center.x)
		out.put_float(center.y)
		out.put_float(view_size.x)
		out.put_float(view_size.y)
		out.put_u16(n_sprites)
		out.put_data(sprites.data_array)
		out.put_u16(n_labels)
		out.put_data(labels.data_array)
		out.put_u16(n_lines)
		out.put_data(lines.data_array)
		out.put_u16(n_parts)
		out.put_data(parts.data_array)
		out.put_var(draws)
		return out.data_array

	func _put_sprite(b: StreamPeerBuffer, s: Sprite2D, tid: int, col: Color, z: int) -> void:
		var t := s.global_transform
		b.put_64(s.get_instance_id())
		b.put_u16(tid)
		b.put_float(t.x.x)
		b.put_float(t.x.y)
		b.put_float(t.y.x)
		b.put_float(t.y.y)
		b.put_float(t.origin.x)
		b.put_float(t.origin.y)
		b.put_float(s.offset.x)
		b.put_float(s.offset.y)
		b.put_u32(col.to_rgba32())
		b.put_16(z)
		var mat := s.material as ShaderMaterial
		if mat and mat.shader and mat.shader.resource_path != "":
			b.put_u8(1)
			var params := {}
			for u in mat.shader.get_shader_uniform_list():
				params[u.name] = mat.get_shader_parameter(u.name)
			b.put_var([mat.shader.resource_path, params])
		else:
			b.put_u8(0)

	func _put_label(b: StreamPeerBuffer, l: Label, col: Color, z: int) -> void:
		var t := l.get_global_transform()
		b.put_64(l.get_instance_id())
		b.put_utf8_string(l.text)
		b.put_float(t.origin.x)
		b.put_float(t.origin.y)
		b.put_float(t.get_scale().x)
		b.put_float(t.get_scale().y)
		b.put_float(l.size.x)
		b.put_float(l.size.y)
		var ls := l.label_settings
		b.put_u16(ls.font_size if ls else 16)
		b.put_u32((ls.font_color if ls else Color.WHITE).to_rgba32())
		b.put_u8(ls.outline_size if ls else 0)
		b.put_u8(l.horizontal_alignment)
		b.put_u32(col.to_rgba32())
		b.put_16(z)
