use rocket::{get, launch, routes};

#[get("/")]
fn hello_world() -> &'static str {
    "Hello, world!"
}

#[launch]
fn rocket() -> _ {
    rocket::build().mount("/", routes![hello_world])
}
