pub mod app;
pub mod state;
pub mod vertex_buffer;
pub mod uniform;
pub mod texture;
pub mod camera;
pub mod instance;
pub mod model;
pub mod resources;
pub mod pipeline;
pub mod light;

use crate::app::App;
use winit::event_loop::EventLoop;

pub fn run() -> anyhow::Result<()> {
    #[cfg(not(target_arch = "wasm32"))]
    {
        env_logger::init();
    }
    #[cfg(target_arch = "wasm32")]
    {
        console_log::init_with_level(log::Level::Info).unwrap_throw();
    }

    let event_loop = EventLoop::with_user_event().build()?;
    let mut app = App::new(
        #[cfg(target_arch = "wasm32")]
        &event_loop,
    );
    event_loop.run_app(&mut app)?;
    
    Ok(())
}
