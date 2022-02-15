mod client;
mod api;
mod database;

use rocket::launch;

#[launch]
fn rocket() -> _ {
    rocket::build()
        .attach(database::Connection::fairing())
        .mount("/api/", api::routes())
        .mount("/", client::routes())
}
