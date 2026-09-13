shader_type canvas_item;

uniform float grayscale_amount : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec4 screen_sample = texture(screen_texture, SCREEN_UV);
	float luminance = dot(screen_sample.rgb, vec3(0.299, 0.587, 0.114));
	vec3 grayscale_color = vec3(luminance);
	
	COLOR = vec4(mix(screen_sample.rgb, grayscale_color, grayscale_amount), screen_sample.a);
}
