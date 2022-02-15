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

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, PartialOrd, Eq, Ord)]
struct Message {
    code: String,
    message: String,
}

#[get("/search")]
async fn empty_search(conn: database::Connection) -> Option<Json<String>> {
    let messages: Vec<Message> = conn.run(all_messages_query).await.ok()?;

    Some(Json(serde_json::to_string_pretty(&messages).ok()?))
}

fn all_messages_query(conn: &mut rusqlite::Connection) -> rusqlite::Result<Vec<Message>> {
    let mut stmt = conn.prepare("SELECT code, message FROM error")?;
    let messages = stmt.query_map([], |row| {
        Ok(Message {
            code: row.get(0)?,
            message: row.get(1)?,
        })
    })?;
    messages.collect()
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

    const HEAP_SIZE: usize = 50_000_000;
    let mut index_writer = index
        .writer(HEAP_SIZE)
        .expect("Database search index error. Failed to create index writer.");

    let message_field = schema
        .get_field("message")
        .expect("Database search index error. Failed to find 'message' field in schema.");
    let code_field = schema
        .get_field("code")
        .expect("Database search index error. Failed to find 'code' field in schema");

    let messages: Vec<Message> = futures::executor::block_on(conn.run(all_messages_query))
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
    let nodes: Vec<ForceNode> = conn.run(all_nodes_query).await.ok()?;

    let edges = tokio::task::spawn_blocking({
        let nodes = nodes.clone();
        || compute_force_edges(nodes)
    })
    .await
    .ok()?;

    let graph = ForceGraph { nodes, edges };

    Some(Json(serde_json::to_string_pretty(&graph).ok()?))
}

fn all_nodes_query(conn: &mut rusqlite::Connection) -> rusqlite::Result<Vec<ForceNode>> {
    let mut stmt = conn.prepare("SELECT id, code, message FROM error")?;
    let nodes = stmt.query_map([], |row| {
        Ok(ForceNode {
            id: row.get(0)?,
            message: Message {
                code: row.get(1)?,
                message: row.get(2)?,
            },
        })
    })?;
    nodes.collect()
}

fn compute_force_edges(nodes: Vec<ForceNode>) -> Vec<ForceEdge> {
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
    edges
}

#[derive(Serialize, Deserialize)]
struct ForceGraph {
    nodes: Vec<ForceNode>,
    edges: Vec<ForceEdge>,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, PartialOrd, Eq, Ord)]
struct ForceNode {
    id: usize,
    message: Message,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, PartialOrd)]
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

#[derive(Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord, Debug)]
struct Frequency {
    code: String,
    count: usize,
}

#[get("/frequency")]
async fn frequency(conn: database::Connection) -> Option<Json<String>> {
    let frequencies: Vec<Frequency> = conn.run(frequencies_query).await.ok()?;

    Some(Json(serde_json::to_string_pretty(&frequencies).ok()?))
}

fn frequencies_query(conn: &mut rusqlite::Connection) -> rusqlite::Result<Vec<Frequency>> {
    let mut stmt = conn.prepare("SELECT code, COUNT(code) FROM error GROUP BY code")?;
    let frequencies = stmt.query_map([], |row| {
        Ok(Frequency {
            code: row.get(0)?,
            count: row.get(1)?,
        })
    })?;
    frequencies.collect()
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::error::Error;

    fn in_memory_database(
        messages: impl IntoIterator<Item = Message>,
    ) -> rusqlite::Result<rusqlite::Connection> {
        let conn = rusqlite::Connection::open_in_memory()?;

        conn.execute(
            "CREATE TABLE error (
                    id INTEGER PRIMARY KEY,
                    code TEXT NOT NULL,
                    message TEXT NOT NULL
                )",
            [],
        )?;

        for message in messages.into_iter() {
            conn.execute(
                "INSERT INTO error (code, message) VALUES (?1, ?2)",
                [message.code, message.message],
            )?;
        }

        Ok(conn)
    }

    #[test]
    fn test_all_messages_query() -> Result<(), Box<dyn Error>> {
        let mut expected_messages = vec![
            Message {
                code: "0001".to_string(),
                message: "message1".to_string(),
            },
            Message {
                code: "0001".to_string(),
                message: "message2".to_string(),
            },
            Message {
                code: "0001".to_string(),
                message: "message3".to_string(),
            },
            Message {
                code: "0002".to_string(),
                message: "message4".to_string(),
            },
            Message {
                code: "0003".to_string(),
                message: "message5".to_string(),
            },
        ];
        let mut conn = in_memory_database(expected_messages.clone())?;

        let mut messages = all_messages_query(&mut conn)?;
        messages.sort();
        expected_messages.sort();
        assert_eq!(messages, expected_messages);

        Ok(())
    }

    #[test]
    fn test_all_nodes_query() -> Result<(), Box<dyn Error>> {
        let messages = vec![
            Message {
                code: "0001".to_string(),
                message: "message1".to_string(),
            },
            Message {
                code: "0001".to_string(),
                message: "message2".to_string(),
            },
            Message {
                code: "0001".to_string(),
                message: "message3".to_string(),
            },
            Message {
                code: "0002".to_string(),
                message: "message4".to_string(),
            },
            Message {
                code: "0003".to_string(),
                message: "message5".to_string(),
            },
        ];
        let mut conn = in_memory_database(messages.clone())?;

        let mut nodes = all_nodes_query(&mut conn)?;
        let mut expected_nodes = vec![
            ForceNode {
                id: 1,
                message: messages[0].clone(),
            },
            ForceNode {
                id: 2,
                message: messages[1].clone(),
            },
            ForceNode {
                id: 3,
                message: messages[2].clone(),
            },
            ForceNode {
                id: 4,
                message: messages[3].clone(),
            },
            ForceNode {
                id: 5,
                message: messages[4].clone(),
            },
        ];
        nodes.sort();
        expected_nodes.sort();
        assert_eq!(nodes, expected_nodes);

        Ok(())
    }

    #[test]
    fn test_compute_force_edges() -> Result<(), Box<dyn Error>> {
        let nodes = vec![
            ForceNode {
                id: 1,
                message: Message {
                    code: "0001".to_string(),
                    message: "a".to_string(),
                },
            },
            ForceNode {
                id: 2,
                message: Message {
                    code: "0001".to_string(),
                    message: "b".to_string(),
                },
            },
            ForceNode {
                id: 3,
                message: Message {
                    code: "0002".to_string(),
                    message: "a".to_string(),
                },
            },
        ];

        let mut edges = compute_force_edges(nodes.clone());
        let mut expected_edges = vec![
            ForceEdge {
                a_id: 1,
                b_id: 2,
                distance: 0.1,
            },
            ForceEdge {
                a_id: 1,
                b_id: 3,
                distance: 1.0,
            },
            ForceEdge {
                a_id: 2,
                b_id: 3,
                distance: 1.1,
            },
        ];
        let key = |edge: &ForceEdge| (edge.a_id, edge.b_id);
        edges.sort_by_key(key);
        expected_edges.sort_by_key(key);

        assert_eq!(edges, expected_edges);

        Ok(())
    }

    #[test]
    fn test_frequencies_query() -> Result<(), Box<dyn Error>> {
        let messages = vec![
            Message {
                code: "0001".to_string(),
                message: "message1".to_string(),
            },
            Message {
                code: "0001".to_string(),
                message: "message2".to_string(),
            },
            Message {
                code: "0001".to_string(),
                message: "message3".to_string(),
            },
            Message {
                code: "0002".to_string(),
                message: "message4".to_string(),
            },
            Message {
                code: "0003".to_string(),
                message: "message5".to_string(),
            },
        ];
        let mut conn = in_memory_database(messages)?;

        let mut frequencies = frequencies_query(&mut conn)?;
        let mut expected_frequencies = vec![
            Frequency {
                code: "0001".to_string(),
                count: 3,
            },
            Frequency {
                code: "0002".to_string(),
                count: 1,
            },
            Frequency {
                code: "0003".to_string(),
                count: 1,
            },
        ];
        frequencies.sort();
        expected_frequencies.sort();
        assert_eq!(frequencies, expected_frequencies);

        Ok(())
    }
}
