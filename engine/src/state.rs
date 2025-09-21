use crate::model::{DrawModel, Model, ModelVertex, Vertex};
use crate::texture::Texture;
use crate::camera::{Camera, CameraController, CameraUniform, Projection};
use crate::instance::{Instance, InstanceRaw};
use crate::resources;
use crate::pipeline;
use std::sync::Arc;
use std::collections::HashMap;
use cgmath::prelude::*;
use wgpu::util::DeviceExt;
use winit::{
    event::*,
    event_loop::ActiveEventLoop,
    keyboard::{PhysicalKey, KeyCode},
    window::Window,
};

#[cfg(target_arch = "wasm32")]
use wasm_bindgen::prelude::*;

// Used for managing render pipelines
#[derive(Hash, Eq, PartialEq, Debug, Clone, Copy)]
enum PipelineType {
    Default,
    Experimental,
}

pub struct State {
    surface: wgpu::Surface<'static>,
    device: wgpu::Device,
    queue: wgpu::Queue,
    config: wgpu::SurfaceConfiguration,
    is_surface_configured: bool,
    current_pipeline: PipelineType,
    pipelines: HashMap<PipelineType, wgpu::RenderPipeline>,
    pub window: Arc<Window>,
    camera: Camera,
    projection: Projection,
    camera_uniform: CameraUniform,
    camera_buffer: wgpu::Buffer,
    camera_bind_group: wgpu::BindGroup,
    camera_controller: CameraController,
    mouse_pressed: bool,
    instances: Vec<Instance>,
    instance_buffer: wgpu::Buffer,
    depth_texture: Texture,
    obj_model: Model,
}

const NUM_INSTANCES_PER_ROW: u32 = 10;

impl State {
    pub fn window_size(&self) -> winit::dpi::PhysicalSize<u32> {
        self.window.inner_size()
    }

    pub async fn new(window: Arc<Window>) -> anyhow::Result<Self> {
        let size = window.inner_size();
        let instance = wgpu::Instance::new(&wgpu::InstanceDescriptor {
            #[cfg(not(target_arch = "wasm32"))]
            backends: wgpu::Backends::PRIMARY,
            #[cfg(target_arch = "wasm32")]
            backends: wgpu::Backends::GL,
            ..Default::default()
        });

        let surface = instance.create_surface(window.clone()).unwrap();
        let adapter = instance
            .request_adapter(&wgpu::RequestAdapterOptions {
                power_preference: wgpu::PowerPreference::default(),
                compatible_surface: Some(&surface),
                force_fallback_adapter: false,
            })
            .await?;

        let (device, queue) = adapter
            .request_device(&wgpu::DeviceDescriptor {
                label: None,
                required_features: wgpu::Features::empty(),
                required_limits: if cfg!(target_arch = "wasm32") {
                    wgpu::Limits::downlevel_webgl2_defaults()
                } else {
                    wgpu::Limits::default()
                },
                memory_hints: Default::default(),
                trace: wgpu::Trace::Off,
            })
            .await?;

        let surface_caps = surface.get_capabilities(&adapter);
        let surface_format = surface_caps
            .formats
            .iter()
            .find(|f| f.is_srgb())
            .copied()
            .unwrap_or(surface_caps.formats[0]);

        let config = wgpu::SurfaceConfiguration {
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            format: surface_format,
            width: size.width,
            height: size.height,
            present_mode: surface_caps.present_modes[0],
            alpha_mode: surface_caps.alpha_modes[0],
            view_formats: vec![],
            desired_maximum_frame_latency: 2,
        };
       
        let depth_texture = Texture::create_depth_texture(&device, &config, "depth_texture");

        let texture_bind_group_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                entries: &[
                    wgpu::BindGroupLayoutEntry {
                        binding: 0,
                        visibility: wgpu::ShaderStages::FRAGMENT,
                        ty: wgpu::BindingType::Texture {
                            multisampled: false,
                            view_dimension: wgpu::TextureViewDimension::D2,
                            sample_type: wgpu::TextureSampleType::Float { filterable: true },
                        },
                        count: None,
                    },
                    wgpu::BindGroupLayoutEntry {
                        binding: 1,
                        visibility: wgpu::ShaderStages::FRAGMENT,
                        ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Filtering),
                        count: None,
                    },
                ],
                label: Some("texture_bind_group_layout"),
            }
        );
       
        let camera = Camera::new(
            (0.0, 5.0, 10.0),
            cgmath::Deg(-90.0),
            cgmath::Deg(-20.0),
        );
        let projection = Projection::new(
            config.width, 
            config.height, 
            cgmath::Deg(45.0), 
            0.1, 
            100.0
        );
        let camera_controller = CameraController::new(4.0, 1.0); // [speed, sensitivity]

        let mut camera_uniform = CameraUniform::new();
        camera_uniform.update_view_proj(&camera, &projection);
        
        let camera_buffer = device.create_buffer_init(
            &wgpu::util::BufferInitDescriptor {
                label: Some("camera_buffer"),
                contents: bytemuck::cast_slice(&[camera_uniform]),
                usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            }
        );

        let camera_bind_group_layout = 
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: Some("camera_bind_group_layout"),
                entries: &[
                    wgpu::BindGroupLayoutEntry {
                        binding: 0,
                        visibility: wgpu::ShaderStages::VERTEX,
                        ty: wgpu::BindingType::Buffer {
                            ty: wgpu::BufferBindingType::Uniform,
                            has_dynamic_offset: false,
                            min_binding_size: None,
                        },
                        count: None,
                    }
                ],
            }
        );

        let camera_bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("camera_bind_group"),
            layout: &camera_bind_group_layout,
            entries: &[
                wgpu::BindGroupEntry {
                    binding: 0,
                    resource: camera_buffer.as_entire_binding(),
                },
            ],
        });

        let obj_model = resources::load_model("cube.obj", &device, &queue, &texture_bind_group_layout)
            .await
            .unwrap();

        const SPACE_BETWEEN: f32 = 3.0;
        let instances = (0..NUM_INSTANCES_PER_ROW).flat_map(|z| {
            (0..NUM_INSTANCES_PER_ROW).map(move |x| {
                let x = SPACE_BETWEEN * (x as f32 - NUM_INSTANCES_PER_ROW as f32 / 2.0);
                let z = SPACE_BETWEEN * (z as f32 - NUM_INSTANCES_PER_ROW as f32 / 2.0);

                let position = cgmath::Vector3 { x, y: 0.0, z };

                let rotation = if position.is_zero() {
                    cgmath::Quaternion::from_axis_angle(cgmath::Vector3::unit_z(), cgmath::Deg(0.0))
                } else {
                    cgmath::Quaternion::from_axis_angle(position.normalize(), cgmath::Deg(45.0))
                };

                Instance {
                    position, rotation,
                }
            })
        }).collect::<Vec<_>>();

        let instance_data = instances.iter().map(Instance::to_raw).collect::<Vec<_>>();
        let instance_buffer = device.create_buffer_init(
            &wgpu::util::BufferInitDescriptor {
                label: Some("Instance Buffer"),
                contents: bytemuck::cast_slice(&instance_data),
                usage: wgpu::BufferUsages::VERTEX,
            }
        );

        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("Shader"),
            source: wgpu::ShaderSource::Wgsl(include_str!("./shaders/shader.wgsl").into()),
        });
        
        let render_pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("Render Pipeline Layout"),
            bind_group_layouts: &[
                &texture_bind_group_layout,
                &camera_bind_group_layout,
            ],
            push_constant_ranges: &[],
        });

        let render_pipeline = pipeline::create_render_pipeline(
            &device, 
            &config, 
            "Shader pipeline",
            &render_pipeline_layout,
            &shader,
            &[ModelVertex::desc(), InstanceRaw::desc()],
        );

        let bw_shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("Experimental shader"),
            source: wgpu::ShaderSource::Wgsl(include_str!("./shaders/bw_shader.wgsl").into()),
        });

        let bw_pipeline = pipeline::create_render_pipeline(
            &device, 
            &config, 
            "BWShader pipeline",
            &render_pipeline_layout,
            &bw_shader,
            &[ModelVertex::desc(), InstanceRaw::desc()],
        );

        let mut pipelines: HashMap<PipelineType, wgpu::RenderPipeline> = HashMap::new();
        pipelines.insert(PipelineType::Default, render_pipeline);
        pipelines.insert(PipelineType::Experimental, bw_pipeline);

        Ok(Self{
            surface,
            device,
            queue,
            config,
            is_surface_configured:false,
            current_pipeline: PipelineType::Default,
            pipelines,
            window,
            camera,
            projection,
            camera_uniform,
            camera_buffer,
            camera_bind_group,
            camera_controller,
            mouse_pressed: false,
            instances,
            instance_buffer,
            depth_texture,
            obj_model,
        })
    }

    pub fn resize(&mut self, width: u32, height: u32) {
        if width > 0 && height > 0 {
            self.config.width = width;
            self.config.height = height;
            self.surface.configure(&self.device, &self.config);
            self.is_surface_configured = true;
        }

        self.projection.resize(width, height);
        self.depth_texture = Texture::create_depth_texture(&self.device, &self.config, "depth_texture");
    }

    pub fn handle_key(&mut self, event_loop: &ActiveEventLoop, code: KeyCode, is_pressed: bool) {
        match (code, is_pressed) {
            (KeyCode::Escape, true) => event_loop.exit(),
            (KeyCode::Tab, true) => {
                self.current_pipeline = match self.current_pipeline {
                    PipelineType::Default => PipelineType::Experimental,
                    PipelineType::Experimental => PipelineType::Default,
                };
            },
            _ => {}
        }
    }

    pub fn render(&mut self) -> Result<(), wgpu::SurfaceError> {
        self.window.request_redraw();

        if !self.is_surface_configured {
            return Ok(());
        }

        let output = self.surface.get_current_texture()?;
        let view = output
            .texture
            .create_view(&wgpu::TextureViewDescriptor::default());
        let mut encoder = self
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("Render encoder"),
            });

        let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            label: Some("Render pass"),
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view: &view,
                resolve_target: None,
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Clear(wgpu::Color {
                        r: 0.4,
                        g: 0.4,
                        b: 0.5,
                        a: 1.0,
                    }),
                    store: wgpu::StoreOp::Store,
                },
            })],
            depth_stencil_attachment: Some(wgpu::RenderPassDepthStencilAttachment {
                view: &self.depth_texture.view,
                depth_ops: Some(wgpu::Operations {
                    load: wgpu::LoadOp::Clear(1.0),
                    store: wgpu::StoreOp::Store,
                }),
                stencil_ops: None,
            }),     
            occlusion_query_set: None,
            timestamp_writes: None,
        });

        let pipeline = self.pipelines.get(&self.current_pipeline).unwrap();
        render_pass.set_pipeline(pipeline);
        render_pass.set_bind_group(1, &self.camera_bind_group, &[]);
        render_pass.set_vertex_buffer(1, self.instance_buffer.slice(..));
        render_pass.draw_model_instanced(&self.obj_model, 0..self.instances.len() as u32, &self.camera_bind_group);
        drop(render_pass);

        self.queue.submit(std::iter::once(encoder.finish()));
        output.present();

        Ok(())
    }

    pub fn update(&mut self, dt: instant::Duration) {
        self.camera_controller.update_camera(&mut self.camera, dt);
        self.camera_uniform.update_view_proj(&self.camera, &self.projection);
        self.queue.write_buffer(&self.camera_buffer, 0, bytemuck::cast_slice(&[self.camera_uniform]));
    }

    pub fn input(&mut self, event: &WindowEvent) -> bool {
        match event {
            WindowEvent::KeyboardInput {
                event:
                    KeyEvent {
                        physical_key: PhysicalKey::Code(_),
                        state: _,
                        ..
                    },
                ..
            } => self.camera_controller.process_events(event),
            WindowEvent::MouseWheel { delta, .. } => {
                self.camera_controller.handle_mouse_scroll(delta);
                true
            }
            WindowEvent::MouseInput {
                button: MouseButton::Left,
                state,
                ..
            } => {
                self.mouse_pressed = *state == ElementState::Pressed;
                true
            }
            _ => false,
        }
    }

    pub fn device_input(&mut self, event: &DeviceEvent) -> bool {
        match event {
            DeviceEvent::MouseMotion { delta } => { 
                if self.mouse_pressed {
                    self.camera_controller.handle_mouse(delta.0, delta.1);
                    true
                } else {
                    false
                }
            }
            _ => false,
        }
    }
}


