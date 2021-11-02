use rocket::fs::{relative, NamedFile};
use rocket::{get, launch, routes};
use rocket::response::content::Json;
use rocket_sync_db_pools::{rusqlite, database};
use serde::Serialize;

#[database("messages")]
struct DatabaseConnection(rusqlite::Connection);

#[derive(Serialize)]
struct Message {
    code: String,
    message: String,
}

#[launch]
fn rocket() -> _ {
    rocket::build()
        .attach(DatabaseConnection::fairing())
        .mount("/api/", routes!(messages))
        .mount("/", routes![app_html, app_js])
}

#[get("/")]
async fn app_html() -> Option<NamedFile> {
    NamedFile::open(relative!("app/app.html")).await.ok()
}

#[get("/app.js")]
async fn app_js() -> Option<NamedFile> {
    NamedFile::open(relative!("app/app.js")).await.ok()
}

#[get("/messages")]
async fn messages(conn: DatabaseConnection) -> Option<Json<String>> {
    let messages: Vec<Message> = conn.run(|conn| { 
        let mut stmt = conn.prepare("SELECT code, message FROM error")?;
        let messages = stmt.query_map([], |row| Ok(
            Message {
            code: row.get(0)?,
            message: row.get(1)?,
        }))?;
        let messages: Result<Vec<Message>, rusqlite::Error> = messages.collect(); 
        messages
    }
    ).await.ok()?;

    Some(Json(serde_json::to_string_pretty(&messages).ok()?)) 
}