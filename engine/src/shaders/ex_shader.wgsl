// engine/src/shaders/ex_shader.wgsl
struct VertexInput {
    @location(0) position: vec3<f32>,
    @location(1) tex_coords: vec2<f32>,
}

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) tex_coords: vec2<f32>,
}

@vertex
fn vs_main(model: VertexInput) -> VertexOutput {
  var out: VertexOutput;
  out.tex_coords = model.tex_coords; 
  out.clip_position = vec4<f32>(model.position, 1.0);
  return out;
}

@group(0) @binding(0)
var t_diffuse: texture_2d<f32>;
@group(0) @binding(1)
var s_diffuse: sampler;


@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let color = textureSample(t_diffuse, s_diffuse, in.tex_coords);

    // Use perceptual luminance
    let brightness = dot(color.rgb, vec3<f32>(0.299, 0.587, 0.114));

    let levels: f32 = 4.97;
    let min_brightness: f32 = 0.13;
    let max_scale: f32 = 1.07; // cap scale to avoid over-brightening

    // Snap to cel shading levels
    let quantized_brightness = mix(min_brightness, 1.0, floor(brightness * levels) / (levels - 1.0));

    // Scale original color to match new brightness, but clamp it
    let scale = clamp(quantized_brightness / max(brightness, 0.01), 0.0, max_scale);
    let cel_color = color.rgb * scale;

    return vec4<f32>(cel_color, color.a);
}
