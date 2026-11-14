shader_type canvas_item;
// Recolours Darth's sprite to show his health (black / yellow / red), adds a
// thin light outline so a dark Darth stays visible on the dark background,
// and supports a white hit flash and a grey "stunned" look.

uniform vec4 tint : source_color = vec4(0.12, 0.12, 0.15, 1.0);
uniform vec4 outline_color : source_color = vec4(0.85, 0.95, 1.0, 0.9);
uniform float outline_px = 1.5;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float grey : hint_range(0.0, 1.0) = 0.0;

varying vec4 mod_color;

void vertex() {
	// Grow the quad a little so the outline has room outside the texture.
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 grow = (UV * 2.0 - 1.0) * outline_px;
	VERTEX += grow;
	UV += grow / tex_size;
	mod_color = COLOR;
}

void fragment() {
	vec4 c = vec4(0.0);
	if (UV.x >= 0.0 && UV.y >= 0.0 && UV.x <= 1.0 && UV.y <= 1.0) {
		c = texture(TEXTURE, UV);
	}
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 body = tint.rgb * (0.55 + 0.6 * lum);
	body = mix(body, vec3(0.45 + 0.35 * lum), grey);
	body = mix(body, vec3(1.0), flash);

	vec2 px = TEXTURE_PIXEL_SIZE * outline_px;
	vec2 offsets[8] = vec2[8](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
			vec2(1.0, 1.0), vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0));
	float n = 0.0;
	for (int i = 0; i < 8; i++) {
		vec2 uv = UV + offsets[i] * px;
		if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
			n = max(n, texture(TEXTURE, uv).a);
		}
	}
	float o = clamp(n - c.a, 0.0, 1.0) * outline_color.a;

	vec3 rgb = mix(outline_color.rgb, body, c.a);
	COLOR = vec4(rgb, max(c.a, o)) * mod_color;
}
