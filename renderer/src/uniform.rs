use wgpu::util::DeviceExt;

pub struct UniformResource<T: bytemuck::Pod> {
    pub buffer: wgpu::Buffer,
    pub bind_group: wgpu::BindGroup,
    pub layout: wgpu::BindGroupLayout,
    _marker: std::marker::PhantomData<T>,
}

impl<T: bytemuck::Pod> UniformResource<T> {
    pub fn new(
        device: &wgpu::Device, 
        label: &str, data: &[T], 
        visibility: wgpu::ShaderStages,
        binding: u32,
    ) -> Self 
    {
        let buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some(&format!("{label}_buffer")),
            contents: bytemuck::cast_slice(data),
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
        });

        let layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some(&format!("{label}_bind_group_layout")),
            entries: &[wgpu::BindGroupLayoutEntry {
                binding,
                visibility,
                ty: wgpu::BindingType::Buffer {
                    ty: wgpu::BufferBindingType::Uniform,
                    has_dynamic_offset: false,
                    min_binding_size: None,
                },
                count: None,
            }],
        });

        let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some(&format!("{label}_bind_group")),
            layout: &layout,
            entries: &[wgpu::BindGroupEntry {
                binding,
                resource: buffer.as_entire_binding(),
            }],
        });

        Self { buffer, bind_group, layout, _marker: std::marker::PhantomData }
    }
}

