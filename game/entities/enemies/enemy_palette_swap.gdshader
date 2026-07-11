shader_type canvas_item;

uniform vec4 source_color_0 : source_color = vec4(0.337255, 0.525490, 0.298039, 1.0);
uniform vec4 source_color_1 : source_color = vec4(0.658824, 0.631373, 0.160784, 1.0);
uniform vec4 source_color_2 : source_color = vec4(0.329412, 0.529412, 0.537255, 1.0);
uniform vec4 source_color_3 : source_color = vec4(0.474510, 0.721569, 0.807843, 1.0);

uniform vec4 target_color_0 : source_color = vec4(0.337255, 0.525490, 0.298039, 1.0);
uniform vec4 target_color_1 : source_color = vec4(0.658824, 0.631373, 0.160784, 1.0);
uniform vec4 target_color_2 : source_color = vec4(0.329412, 0.529412, 0.537255, 1.0);
uniform vec4 target_color_3 : source_color = vec4(0.474510, 0.721569, 0.807843, 1.0);
uniform float threshold : hint_range(0.0, 0.2, 0.001) = 0.03;

vec3 swap_color(vec3 input_rgb, vec3 source_rgb, vec3 target_rgb) {
    float match_amount = 1.0 - step(threshold, distance(input_rgb, source_rgb));
    return mix(input_rgb, target_rgb, match_amount);
}

void fragment() {
    vec4 texture_color = texture(TEXTURE, UV);
    vec3 swapped_color = texture_color.rgb;

    swapped_color = swap_color(swapped_color, source_color_0.rgb, target_color_0.rgb);
    swapped_color = swap_color(swapped_color, source_color_1.rgb, target_color_1.rgb);
    swapped_color = swap_color(swapped_color, source_color_2.rgb, target_color_2.rgb);
    swapped_color = swap_color(swapped_color, source_color_3.rgb, target_color_3.rgb);

    COLOR = vec4(swapped_color, texture_color.a) * COLOR;
}
