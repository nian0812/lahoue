shader_type canvas_item;
render_mode unshaded;
uniform sampler2D dirt_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D grass_texture : source_color, repeat_enable, filter_linear_mipmap;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
vec3 varied(sampler2D tex, vec2 p) {
    vec2 i = floor(p * 0.37), f = fract(p * 0.37);
    f = f*f*(3.0-2.0*f);
    vec2 a = vec2(hash(i), hash(i+17.0))*7.0;
    vec2 b = vec2(hash(i+vec2(1,0)),hash(i+vec2(18,17)))*7.0;
    vec2 c = vec2(hash(i+vec2(0,1)),hash(i+vec2(17,18)))*7.0;
    vec2 d = vec2(hash(i+vec2(1,1)),hash(i+vec2(18,18)))*7.0;
    // Mirrored sampling keeps each approved crop continuous at its edges.
    vec2 ua = abs(fract((p+a)*0.5)*2.0-1.0);
    vec2 ub = abs(fract((p+b)*0.5)*2.0-1.0);
    vec2 uc = abs(fract((p+c)*0.5)*2.0-1.0);
    vec2 ud = abs(fract((p+d)*0.5)*2.0-1.0);
    return mix(mix(texture(tex,ua).rgb,texture(tex,ub).rgb,f.x),mix(texture(tex,uc).rgb,texture(tex,ud).rgb,f.x),f.y);
}
void fragment() {
    vec2 uv = UV;
    vec3 grass = varied(grass_texture, uv * 2.0);
    vec3 dirt = varied(dirt_texture, uv * 0.5);
    float patches = smoothstep(0.36,0.78,noise(uv*0.16)+noise(uv*0.47)*0.16);
    vec3 ground = mix(grass * vec3(0.72,0.77,0.64),dirt * vec3(0.92,0.88,0.76),patches*0.82);
    COLOR = vec4(ground * (0.92+noise(uv*0.73)*0.16),1.0);
}
