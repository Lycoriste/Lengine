struct CameraUniform {
    view_proj: mat4x4<f32>,
    view: mat4x4<f32>,
};

struct LightUniform {
    position: vec3<f32>,
    color: vec3<f32>,
}

@group(1) @binding(0)
var<uniform> camera: CameraUniform;

@group(2) @binding(0)
var<uniform> light: LightUniform;

struct VertexInput {
    @location(0) position: vec3<f32>,
    @location(1) tex_coords: vec2<f32>,
    @location(2) normal: vec3<f32>,
    @location(3) tangent: vec4<f32>,
}

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) tex_coords: vec2<f32>,
    @location(1) view_pos: vec3<f32>,
    @location(2) tangent: vec3<f32>,
    @location(3) bitangent: vec3<f32>,
    @location(4) normal: vec3<f32>,
}

struct InstanceInput {
    @location(5) model_matrix_0: vec4<f32>,
    @location(6) model_matrix_1: vec4<f32>,
    @location(7) model_matrix_2: vec4<f32>,
    @location(8) model_matrix_3: vec4<f32>,
    @location(9) normal_matrix_0: vec3<f32>,
    @location(10) normal_matrix_1: vec3<f32>,
    @location(11) normal_matrix_2: vec3<f32>,
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
  let model_matrix3x3 = mat3x3<f32>(
    model_matrix[0].xyz,
    model_matrix[1].xyz,
    model_matrix[2].xyz
  );
  let normal_matrix = mat3x3<f32> (
    instance.normal_matrix_0,
    instance.normal_matrix_1,
    instance.normal_matrix_2,
  );
  let view_matrix3x3 = mat3x3<f32>(
    camera.view[0].xyz,
    camera.view[1].xyz,
    camera.view[2].xyz
  );
  
  out.normal = normalize(normal_matrix * model.normal);
  out.tangent = normalize(model_matrix3x3 * model.tangent.xyz);
  out.bitangent = normalize(cross(out.normal, out.tangent)) * model.tangent.w;

  out.normal = out.normal * view_matrix3x3;
  out.tangent = out.tangent * view_matrix3x3;
  out.bitangent = out.bitangent * view_matrix3x3;

  out.view_pos = (camera.view * model_matrix * vec4<f32>(model.position, 1.0)).xyz;
  out.clip_position = camera.view_proj * model_matrix * vec4<f32>(model.position, 1.0);
  out.tex_coords = model.tex_coords;

  return out;
}

@group(0) @binding(0)
var t_diffuse: texture_2d<f32>;
@group(0) @binding(1)
var t_sampler: sampler;
@group(0)@binding(2)
var t_normal: texture_2d<f32>;

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let tbn = mat3x3<f32>(in.tangent, in.bitangent, in.normal);

    let obj_color: vec4<f32> = textureSample(t_diffuse, t_sampler, in.tex_coords);
    let obj_norm: vec4<f32> = textureSample(t_normal, t_sampler, in.tex_coords);
    let tangent_normal = normalize(obj_norm.xyz * 2.0 - 1.0);
    let view_space_normal = normalize(tbn * tangent_normal);

    let AMBIENT_STRENGTH = 0.15;
    let ambient_color = light.color * AMBIENT_STRENGTH;
    
    let light_pos_view = (camera.view * vec4<f32>(light.position, 1.0)).xyz;
    let light_dir = normalize(light_pos_view - in.view_pos);
    let view_dir = normalize(-in.view_pos);
    let half_dir = normalize(view_dir + light_dir);

    let diffuse_strength = max(dot(view_space_normal, light_dir), 0.0);
    let diffuse_color = light.color * diffuse_strength;

    let specular_strength = pow(max(dot(view_space_normal, half_dir), 0.0), 32.0);
    let specular_color = specular_strength * light.color;
    let result = (ambient_color + diffuse_color + specular_color) * obj_color.xyz;
    
    return vec4<f32>(result, obj_color.a);
}

