use rocket_sync_db_pools::database;

#[database("messages")]
pub struct Connection(rusqlite::Connection);
