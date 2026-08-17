shader_type canvas_item;

uniform vec4 water_color : source_color = vec4(0.2, 0.4, 0.6, 0.8);
uniform vec4 highlight_color : source_color = vec4(0.4, 0.6, 0.8, 1.0);
uniform float speed = 1.0;
uniform float frequency = 5.0;
uniform float amplitude = 0.02;

void fragment() {
	vec2 uv = UV;
	
	// Create animated ripples
	float wave_x = sin(uv.y * frequency + TIME * speed) * amplitude;
	float wave_y = cos(uv.x * frequency + TIME * speed) * amplitude;
	
	// Add some noise/distortion
	float noise = sin(uv.x * 20.0 + TIME) * cos(uv.y * 20.0 + TIME);
	
	// Calculate final color based on wave height
	float height = wave_x + wave_y + noise * 0.01;
	vec4 final_color = mix(water_color, highlight_color, height * 10.0 + 0.5);
	
	COLOR = final_color;
}
