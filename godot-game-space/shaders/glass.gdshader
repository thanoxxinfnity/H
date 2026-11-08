shader_type canvas_item;
// Glassmorphism: blurred backdrop + cool tint + rounded corners + soft neon rim.
// Needs the screen texture, so only show it while the drawer is open.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.10, 0.02, 0.04, 0.70);
uniform vec4 rim : source_color = vec4(1.0, 0.12, 0.24, 1.0);
uniform float blur : hint_range(0.0, 8.0) = 3.0;
uniform float radius = 28.0;
uniform vec2 rect_size = vec2(360.0, 600.0);

float round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * rect_size;
	float d = round_box(p, rect_size * 0.5, radius);
	float shape = 1.0 - smoothstep(-1.0, 1.0, d);

	vec2 px = SCREEN_PIXEL_SIZE * blur;
	vec3 c = texture(screen_tex, SCREEN_UV).rgb * 0.22;
	c += texture(screen_tex, SCREEN_UV + vec2(px.x, 0.0)).rgb * 0.13;
	c += texture(screen_tex, SCREEN_UV - vec2(px.x, 0.0)).rgb * 0.13;
	c += texture(screen_tex, SCREEN_UV + vec2(0.0, px.y)).rgb * 0.13;
	c += texture(screen_tex, SCREEN_UV - vec2(0.0, px.y)).rgb * 0.13;
	c += texture(screen_tex, SCREEN_UV + px).rgb * 0.065;
	c += texture(screen_tex, SCREEN_UV - px).rgb * 0.065;
	c += texture(screen_tex, SCREEN_UV + vec2(px.x, -px.y)).rgb * 0.065;
	c += texture(screen_tex, SCREEN_UV + vec2(-px.x, px.y)).rgb * 0.065;

	vec3 col = mix(c, tint.rgb, tint.a);
	col += vec3(0.05) * (1.0 - UV.y); // faint top sheen
	float edge = smoothstep(-3.0, 0.0, d) * (1.0 - smoothstep(0.0, 1.5, d));
	col = mix(col, rim.rgb, edge * 0.7);
	COLOR = vec4(col, shape);
}
