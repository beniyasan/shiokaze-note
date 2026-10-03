shader_type canvas_item;
// Chromatic aberration plus a light radial blur for the hottest moments
// (rainbow cue, EPIC flip, LEGENDARY crack/shatter). The node is hidden while
// `amount` is zero, so normal play pays nothing for it.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec2 focus = vec2(0.5, 0.47);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - focus;
	float dist = length(dir);
	vec2 off = dir * amount * 0.018 * (0.35 + dist * 1.8);
	vec3 col;
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;
	// Three extra taps toward the focus give a short zoom blur.
	vec3 blur = vec3(0.0);
	for (int i = 1; i <= 3; i++) {
		blur += texture(screen_tex, uv - dir * amount * 0.012 * float(i)).rgb;
	}
	col = mix(col, blur / 3.0, amount * 0.35);
	COLOR = vec4(col, 1.0);
}
