mod api;
mod client;
mod database;

use rocket::launch;

/// The main function that acts as the entry point for the rocket webserver.
/// Requests that begin with /api are handled by the routes in the api module.
/// All other requests are handled by the client. The client's resources are
/// initially served by the client module. Navigation is generally handled
/// on the client side.
#[launch]
fn rocket() -> _ {
    rocket::build()
        .attach(database::Connection::fairing())
        .mount("/api/", api::routes())
        .mount("/", client::routes())
}
