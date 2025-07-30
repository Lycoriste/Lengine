// engine/src/shaders/ex_shader.wgsl
// Cache the shader -- nearest neighbor lags

struct CameraUniform {
    view_proj: mat4x4<f32>,
};
@group(1) @binding(0)
var<uniform> camera: CameraUniform;

struct VertexInput {
    @location(0) position: vec3<f32>,
    @location(1) tex_coords: vec2<f32>,
}

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) tex_coords: vec2<f32>,
}

struct InstanceInput {
    @location(5) model_matrix_0: vec4<f32>,
    @location(6) model_matrix_1: vec4<f32>,
    @location(7) model_matrix_2: vec4<f32>,
    @location(8) model_matrix_3: vec4<f32>,
};

@vertex
fn vs_main(model: VertexInput, instance: InstanceInput) -> VertexOutput {
  var out: VertexOutput;
  let model_matrix = mat4x4<f32> (
    instance.model_matrix_0,
    instance.model_matrix_1,
    instance.model_matrix_2,
    instance.model_matrix_3,
  );

  out.tex_coords = model.tex_coords; 
  out.clip_position = camera.view_proj * model_matrix * vec4<f32>(model.position, 1.0);
  return out;
}

@group(0) @binding(0)
var t_diffuse: texture_2d<f32>;
@group(0) @binding(1)
var s_diffuse: sampler;

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let tex_size: vec2<f32> = vec2<f32>(textureDimensions(t_diffuse, 0));
    let uv: vec2<f32> = in.tex_coords;

    var color_sum: vec3<f32> = vec3<f32>(0.0, 0.0, 0.0);
    var count: f32 = 0.0;
    let window_size = 6;

    for (var y: i32 = -window_size; y <= window_size; y = y + 1) {
        for (var x: i32 = -window_size; x <= window_size; x = x + 1) {
            let offset = vec2<f32>(f32(x), f32(y)) / tex_size;
            let sample_uv = uv + offset;
            let clamped_uv = clamp(sample_uv, vec2<f32>(0.0), vec2<f32>(1.0));
            color_sum = color_sum + textureSample(t_diffuse, s_diffuse, clamped_uv).rgb;
            count = count + 1.0;
        }
    }

    var color = color_sum / count;
    color = closest_palette_color(color);

    return vec4<f32>(color, 1.0);
}

fn closest_palette_color(color: vec3<f32>) -> vec3<f32> {
    var palette = array<vec3<f32>, 41>(
        // Near-black & darks
        vec3<f32>(0.05, 0.05, 0.05),    // near-black
        vec3<f32>(0.1, 0.07, 0.05),     // very dark brown
        vec3<f32>(0.12, 0.12, 0.12),    // charcoal
        vec3<f32>(0.18, 0.18, 0.18),    // dark slate gray
        vec3<f32>(0.2, 0.15, 0.1),      // dark warm brown
        vec3<f32>(0.25, 0.22, 0.2),     // dark taupe

        // Warm browns & reds
        vec3<f32>(0.5, 0.1, 0.0),       // dark brown
        vec3<f32>(0.65, 0.2, 0.05),     // burnt sienna
        vec3<f32>(0.8, 0.3, 0.0),       // burnt orange
        vec3<f32>(0.85, 0.4, 0.2),      // warm terracotta
        vec3<f32>(0.9, 0.5, 0.3),       // clay
        vec3<f32>(0.95, 0.6, 0.4),      // peachy orange
        vec3<f32>(1.0, 0.75, 0.5),      // warm peach

        // Skin tones & warm highlights
        vec3<f32>(0.4, 0.3, 0.3),       // warm midtone
        vec3<f32>(0.6, 0.4, 0.3),       // base skin
        vec3<f32>(0.8, 0.6, 0.5),       // skin highlight
        vec3<f32>(1.0, 0.8, 0.6),       // soft light
        vec3<f32>(1.0, 1.0, 1.0),       // white

        // Yellows and golds (for hair & highlights)
        vec3<f32>(0.8, 0.7, 0.2),       // mustard yellow
        vec3<f32>(0.9, 0.85, 0.3),      // goldenrod
        vec3<f32>(1.0, 0.9, 0.4),       // bright gold
        vec3<f32>(1.0, 1.0, 0.0),       // bright yellow

        // Greyscale range
        vec3<f32>(0.25, 0.25, 0.25),    // dark gray
        vec3<f32>(0.4, 0.4, 0.4),       // medium gray
        vec3<f32>(0.6, 0.6, 0.6),       // light gray
        vec3<f32>(0.75, 0.75, 0.75),    // lighter gray
        vec3<f32>(0.9, 0.9, 0.9),       // near-white gray

        // Cool blues & greens
        vec3<f32>(0.2, 0.4, 0.8),       // deep blue
        vec3<f32>(0.4, 0.7, 1.0),       // sky blue
        vec3<f32>(0.3, 0.6, 0.5),       // teal
        vec3<f32>(0.6, 0.8, 0.7),       // mint green
        vec3<f32>(0.1, 0.5, 0.2),       // dark green
        vec3<f32>(0.4, 0.7, 0.3),       // olive green

        // Purples & accents
        vec3<f32>(0.6, 0.4, 0.7),       // purple
        vec3<f32>(0.7, 0.5, 0.8),       // lavender
        vec3<f32>(0.9, 0.4, 0.4),       // blush red
        vec3<f32>(0.4, 0.3, 0.6),       // indigo

        // Neutrals & beige
        vec3<f32>(0.8, 0.7, 0.6),       // beige / tan
        vec3<f32>(0.9, 0.85, 0.8),      // light beige
        vec3<f32>(0.7, 0.6, 0.5),       // taupe
        vec3<f32>(0.55, 0.45, 0.35)     // warm gray-brown
    );

    var min_dist: f32 = 1e10;
    var closest: vec3<f32> = palette[0];
    
    let lab_color = rgb_to_lab(color);

    for (var i: u32 = 0u; i < 41u; i = i + 1u) {
        let lab_palette = rgb_to_lab(palette[i]);
        let d = distance(lab_color, lab_palette); // Euclidean in Lab space
        if (d < min_dist) {
            min_dist = d;
            closest = palette[i];
        }
    }

    return closest;
}

fn srgb_to_linear(c: f32) -> f32 {
    if (c <= 0.04045) {
        return c / 12.92;
    } else {
        return pow((c + 0.055) / 1.055, 2.4);
    }
}

fn rgb_to_linear(rgb: vec3<f32>) -> vec3<f32> {
    return vec3<f32>(
        srgb_to_linear(rgb.r),
        srgb_to_linear(rgb.g),
        srgb_to_linear(rgb.b)
    );
}

fn linear_rgb_to_xyz(rgb: vec3<f32>) -> vec3<f32> {
    let x = 0.4124564 * rgb.r + 0.3575761 * rgb.g + 0.1804375 * rgb.b;
    let y = 0.2126729 * rgb.r + 0.7151522 * rgb.g + 0.0721750 * rgb.b;
    let z = 0.0193339 * rgb.r + 0.1191920 * rgb.g + 0.9503041 * rgb.b;
    return vec3<f32>(x, y, z);
}

fn f_lab(t: f32) -> f32 {
    if (t > 0.008856) {
        return pow(t, 1.0 / 3.0);
    } else {
        return (7.787 * t) + (16.0 / 116.0);
    }
}

fn xyz_to_lab(xyz: vec3<f32>) -> vec3<f32> {
    var REF_X: f32 = 0.95047;
    var REF_Y: f32 = 1.00000;
    var REF_Z: f32 = 1.08883;

    let fx = f_lab(xyz.x / REF_X);
    let fy = f_lab(xyz.y / REF_Y);
    let fz = f_lab(xyz.z / REF_Z);

    let L = (116.0 * fy) - 16.0;
    let a = 500.0 * (fx - fy);
    let b = 200.0 * (fy - fz);

    return vec3<f32>(L, a, b);
}

fn rgb_to_lab(rgb: vec3<f32>) -> vec3<f32> {
    let linear_rgb = rgb_to_linear(rgb);
    let xyz = linear_rgb_to_xyz(linear_rgb);
    return xyz_to_lab(xyz);
}
