shader_type canvas_item;
// AMD FidelityFX CAS (Contrast Adaptive Sharpening), plus-shaped 5-tap version.
// Apply it to the TextureRect that shows the low-resolution game viewport: the texture is
// upscaled with linear filtering by the GPU, then sharpened here at output resolution.

uniform float sharpness : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE; // one texel of the (lower resolution) source image
	vec3 b = texture(TEXTURE, UV + vec2(0.0, -px.y)).rgb;
	vec3 d = texture(TEXTURE, UV + vec2(-px.x, 0.0)).rgb;
	vec3 e = texture(TEXTURE, UV).rgb;
	vec3 f = texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb;
	vec3 h = texture(TEXTURE, UV + vec2(0.0, px.y)).rgb;

	vec3 mn = min(min(min(d, e), min(f, b)), h);
	vec3 mx = max(max(max(d, e), max(f, b)), h);

	// Per-channel adaptive amount: less sharpening where the local contrast is already high.
	vec3 amp = sqrt(clamp(min(mn, vec3(1.0) - mx) / max(mx, vec3(0.0001)), 0.0, 1.0));
	float peak = -1.0 / mix(8.0, 5.0, sharpness);
	vec3 w = amp * peak;
	vec3 rcp_w = vec3(1.0) / (vec3(1.0) + 4.0 * w);

	vec3 col = clamp(((b + d + f + h) * w + e) * rcp_w, 0.0, 1.0);
	COLOR = vec4(col, 1.0);
}
