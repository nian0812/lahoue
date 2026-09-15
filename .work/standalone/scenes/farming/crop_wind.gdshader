shader_type canvas_item;

uniform float wind_speed = 2.0;
uniform float wind_strength = 0.05;
uniform float plant_height = 1.0; // Assume origin is at the bottom, so higher y = lower displacement if origin is bottom. Wait, Godot 2D origin is top-left usually. Let's assume UV.y goes from 0 to 1. If 1 is bottom, we want more sway at 0.

void vertex() {
	// Simple sway based on time and vertical position (UV.y)
	// If UV.y = 1.0 is the bottom (roots), sway should be zero there.
	// We'll use (1.0 - UV.y) as the sway factor.
	float sway_factor = 1.0 - UV.y;
	
	// Add some variation based on world position
	float offset = VERTEX.x * 0.01;
	
	VERTEX.x += sin(TIME * wind_speed + offset) * wind_strength * sway_factor * 20.0;
}
