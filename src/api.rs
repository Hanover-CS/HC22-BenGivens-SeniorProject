use crate::database;
use once_cell::sync::OnceCell;
use rocket::response::content::Json;
use rocket::{get, routes, Route};
use rocket_sync_db_pools::rusqlite;
use serde::{Deserialize, Serialize};
use tantivy::collector::TopDocs;
use tantivy::query::QueryParser;
use tantivy::schema::{Field, Schema, STORED, TEXT};
use tantivy::Document;
use tantivy::{Index, ReloadPolicy};
use tempfile::TempDir;

pub fn routes() -> Vec<Route> {
    routes!(empty_search, search, force_graph, frequency, length)
}

#[derive(Serialize, Deserialize)]
struct Message {
    code: String,
    message: String,
}

#[get("/search")]
async fn empty_search(conn: database::Connection) -> Option<Json<String>> {
    let messages: Vec<Message> = conn
        .run(|conn| {
            let mut stmt = conn.prepare("SELECT code, message FROM error")?;
            let messages = stmt.query_map([], |row| {
                Ok(Message {
                    code: row.get(0)?,
                    message: row.get(1)?,
                })
            })?;
            let messages: Result<Vec<Message>, rusqlite::Error> = messages.collect();
            messages
        })
        .await
        .ok()?;

    Some(Json(serde_json::to_string_pretty(&messages).ok()?))
}

#[get("/search/<query>")]
async fn search(query: String, conn: database::Connection) -> Option<Json<String>> {
    static INDEX: OnceCell<SearchIndex> = OnceCell::new();
    let SearchIndex {
        index,
        code_field,
        message_field,
        ..
    } = INDEX.get_or_init(|| create_search_index(conn));

    let reader = index
        .reader_builder()
        .reload_policy(ReloadPolicy::OnCommit)
        .try_into()
        .ok()?;
    let query_parser = QueryParser::for_index(&index, vec![*message_field]);

    let searcher = reader.searcher();
    let query = query_parser.parse_query(&query).ok()?;

    let results = searcher.search(&query, &TopDocs::with_limit(50)).ok()?;

    let mut messages: Vec<Message> = Vec::new();
    for (_score, address) in results {
        let retrieved_doc = searcher.doc(address).ok()?;
        let code = retrieved_doc.get_first(*code_field)?.text()?.to_owned();
        let message = retrieved_doc.get_first(*message_field)?.text()?.to_owned();
        messages.push(Message { code, message })
    }

    Some(Json(serde_json::to_string_pretty(&messages).ok()?))
}

struct SearchIndex {
    _index_directory: TempDir,
    index: Index,
    code_field: Field,
    message_field: Field,
}

fn create_search_index(conn: database::Connection) -> SearchIndex {
    let index_directory =
        TempDir::new().expect("Database search index error. Failed to create temporary directory.");
    let mut schema_builder = Schema::builder();
    schema_builder.add_text_field("message", TEXT | STORED);
    schema_builder.add_text_field("code", TEXT | STORED);
    let schema = schema_builder.build();

    let index = Index::create_in_dir(&index_directory, schema.clone())
        .expect("Database search index error. Failed to create index in directory.");
    let mut index_writer = index
        .writer(50_000_000)
        .expect("Database search index error. Failed to create index writer.");

    let message_field = schema
        .get_field("message")
        .expect("Database search index error. Failed to find 'message' field in schema.");
    let code_field = schema
        .get_field("code")
        .expect("Database search index error. Failed to find 'code' field in schema");

    let messages: Vec<Message> = futures::executor::block_on(conn.run(|conn| {
        let mut stmt = conn.prepare("SELECT code, message FROM error")?;
        let messages = stmt.query_map([], |row| {
            Ok(Message {
                code: row.get(0)?,
                message: row.get(1)?,
            })
        })?;
        let messages: Result<Vec<Message>, rusqlite::Error> = messages.collect();
        messages
    }))
    .expect("Database search index error. Failed to retrieve messages from database.");

    for message in messages {
        let mut doc = Document::default();
        doc.add_text(message_field, message.message);
        doc.add_text(code_field, message.code);
        index_writer.add_document(doc);
    }
    index_writer
        .commit()
        .expect("Database search index error. Failed to commit write to index.");

    SearchIndex {
        index,
        code_field,
        message_field,
        _index_directory: index_directory,
    }
}

#[get("/force_graph")]
async fn force_graph(conn: database::Connection) -> Option<Json<String>> {
    let nodes: Vec<ForceNode> = conn
        .run(|conn| {
            let mut stmt = conn.prepare("SELECT id, code, message FROM error")?;
            let messages = stmt.query_map([], |row| {
                Ok(ForceNode {
                    id: row.get(0)?,
                    message: Message {
                        code: row.get(1)?,
                        message: row.get(2)?,
                    },
                })
            })?;
            let nodes: Result<Vec<ForceNode>, rusqlite::Error> = messages.collect();
            nodes
        })
        .await
        .ok()?;

    let (nodes, edges) = tokio::task::spawn_blocking(move || {
        let mut edges = Vec::new();
        for (i, node_a) in nodes.iter().enumerate() {
            for node_b in nodes.iter().skip(i + 1) {
                edges.push(ForceEdge {
                    a_id: node_a.id,
                    b_id: node_b.id,
                    distance: distance(&node_a.message, &node_b.message),
                });
            }
        }
        (nodes, edges)
    })
    .await
    .ok()?;

    let graph = ForceGraph { nodes, edges };

    Some(Json(serde_json::to_string_pretty(&graph).ok()?))
}

#[derive(Serialize, Deserialize)]
struct ForceGraph {
    nodes: Vec<ForceNode>,
    edges: Vec<ForceEdge>,
}

#[derive(Serialize, Deserialize)]
struct ForceNode {
    id: usize,
    message: Message,
}

#[derive(Serialize, Deserialize)]
struct ForceEdge {
    a_id: usize,
    b_id: usize,
    distance: f64,
}

fn distance(a: &Message, b: &Message) -> f64 {
    const CODE_WEIGHT: f64 = 1.0;
    const MESSAGE_WEIGHT: f64 = 0.1;

    let code_similarity = distance::damerau_levenshtein(&a.code, &b.code) as f64;
    let message_similarity = distance::damerau_levenshtein(&a.message, &b.message) as f64;

    code_similarity * CODE_WEIGHT + message_similarity * MESSAGE_WEIGHT
}

#[derive(Serialize, Deserialize)]
struct Frequency {
    code: String,
    count: usize,
}

#[get("/frequency")]
async fn frequency(conn: database::Connection) -> Option<Json<String>> {
    let frequencies: Vec<Frequency> = conn
        .run(|conn| {
            let mut stmt = conn.prepare("SELECT code, COUNT(code) FROM error GROUP BY code")?;
            let frequencies = stmt.query_map([], |row| {
                Ok(Frequency {
                    code: row.get(0)?,
                    count: row.get(1)?,
                })
            })?;
            let frequencies: Result<Vec<Frequency>, rusqlite::Error> = frequencies.collect();
            frequencies
        })
        .await
        .ok()?;

    Some(Json(serde_json::to_string_pretty(&frequencies).ok()?))
}

#[get("/length")]
async fn length(conn: database::Connection) -> Option<Json<String>> {
    let lengths: Vec<usize> = conn
        .run(|conn| {
            let mut stmt = conn.prepare("SELECT LENGTH(message) FROM error")?;
            let lengths = stmt.query_map([], |row| Ok(row.get(0)?))?;
            let lengths: Result<Vec<usize>, rusqlite::Error> = lengths.collect();
            lengths
        })
        .await
        .ok()?;

    Some(Json(serde_json::to_string_pretty(&lengths).ok()?))
}
