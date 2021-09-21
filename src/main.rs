use rocket::fs::{relative, NamedFile};
use rocket::{get, launch, routes};

#[launch]
fn rocket() -> _ {
    rocket::build().mount("/", routes![app_html, app_js])
}

#[get("/")]
async fn app_html() -> Option<NamedFile> {
    NamedFile::open(relative!("app/app.html")).await.ok()
}

#[get("/app.js")]
async fn app_js() -> Option<NamedFile> {
    NamedFile::open(relative!("app/app.js")).await.ok()
}
