use rocket::fs::{relative, NamedFile};
use rocket::{get, launch, routes};
use rocket::response::content::Json;
use rocket_sync_db_pools::{rusqlite, database};
use serde::Serialize;
use tantivy::collector::TopDocs;
use tantivy::query::QueryParser;
use tantivy::{Index, ReloadPolicy};
use tantivy::schema::{STORED, Schema, TEXT};
use tantivy::Document;
use tempfile::TempDir;

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
        .mount("/api/", routes!(messages, search))
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

#[get("/search/<query>")]
async fn search(query: String, conn: DatabaseConnection) -> Option<Json<String>> {
    let index_path = TempDir::new().ok()?;
    let mut schema_builder = Schema::builder();
    schema_builder.add_text_field("message", TEXT | STORED);
    let schema = schema_builder.build();
    
    let index = Index::create_in_dir(&index_path, schema.clone()).ok()?;
    let mut index_writer = index.writer(50_000_000).ok()?;
    
    let message_field = schema.get_field("message")?;
    
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
    
    for message in messages {
        let mut doc = Document::default();
        doc.add_text(message_field, message.message);
        index_writer.add_document(doc);
    }
    index_writer.commit().ok()?;
    
    let reader = index.reader_builder().reload_policy(ReloadPolicy::OnCommit).try_into().ok()?;
    let searcher = reader.searcher();
    let query_parser = QueryParser::for_index(&index, vec![message_field]);
    let query = query_parser.parse_query(&query).ok()?;
    
    let results = searcher.search(&query, &TopDocs::with_limit(10)).ok()?;
    
    let mut messages = Vec::new();
    for (_score, address) in results {
        let retrieved_doc = searcher.doc(address).ok()?;
        messages.push(schema.to_json(&retrieved_doc));
    }
    
    Some(Json(serde_json::to_string_pretty(&messages).ok()?))
}