#[cfg(feature = "ssr")]
#[tokio::main]
async fn main() {
    use axum::Router;
    use leptos::logging;
    use leptos::prelude::*;
    use leptos_axum::{LeptosRoutes, generate_route_list};
    use leptos_image::*;
    use start_axum::app::*;
    use tokio::net::TcpListener;

    // Composite App State with the optimizer and leptos options.
    #[derive(Clone, axum::extract::FromRef)]
    struct AppState {
        leptos_options: LeptosOptions,
        optimizer: leptos_image::ImageOptimizer,
    }
    simple_logger::init_with_level(log::Level::Info).expect("couldn't initialize logging");

    // Setting get_configuration(None) means we'll be using cargo-leptos's env values
    // For deployment these variables are:
    // <https://github.com/leptos-rs/start-axum#executing-a-server-on-a-remote-machine-without-the-toolchain>
    // Alternately a file can be specified such as Some("Cargo.toml")
    // The file would need to be included with the executable when moved to deployment
    let conf = get_configuration(None).unwrap();
    let leptos_options = conf.leptos_options;
    let addr = leptos_options.site_addr;
    let routes = generate_route_list(App);

    let root = leptos_options.site_root.to_string();

    let state = AppState {
        leptos_options,
        optimizer: ImageOptimizer::new("/cache/image", root, 1),
    };

    // Build Router.
    let app = Router::new()
        // Add a handler for serving the cached images.
        .image_cache_route(&state)
        // Provide the optimizer to leptos context.
        .leptos_routes_with_context(&state, routes, state.optimizer.provide_context(), {
            let leptos_options = state.leptos_options.clone();
            move || shell(leptos_options.clone())
        })
        .fallback(leptos_axum::file_and_error_handler_with_context::<
            AppState,
            _,
        >(state.optimizer.provide_context(), shell))
        .with_state(state);

    // run our app with hyper
    // `axum::Server` is a re-export of `hyper::Server`
    let listener = TcpListener::bind(&addr).await.unwrap();
    logging::log!("listening on http://{}", &addr);
    axum::serve(listener, app.into_make_service())
        .await
        .unwrap();
}

#[cfg(not(feature = "ssr"))]
pub fn main() {
    // no client-side main function
    // unless we want this to work with e.g., Trunk for a purely client-side app
    // see lib.rs for hydration function instead
}
