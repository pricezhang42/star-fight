shader_type canvas_item;
// Fades the square picture out into a soft circle so it blends with space.
uniform float inner = 0.16;
uniform float outer = 0.5;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = distance(UV, vec2(0.5));
	c.a *= 1.0 - smoothstep(inner, outer, d);
	COLOR = c;
}
