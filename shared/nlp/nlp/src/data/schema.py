import sqlite3
import os

CREATE_MANIFEST_TABLE = """
CREATE TABLE IF NOT EXISTS file_manifest (
    source_doc_id TEXT PRIMARY KEY,
    path TEXT UNIQUE NOT NULL,
    source_type TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    processing_status TEXT NOT NULL,
    last_processed_ts REAL,
    error_message TEXT
);
"""

CREATE_CHUNKS_TABLE = """
CREATE TABLE IF NOT EXISTS text_chunks (
    chunk_id TEXT PRIMARY KEY,
    source_doc_id TEXT NOT NULL,
    location_metadata TEXT NOT NULL,
    raw_text TEXT NOT NULL,
    normalized_text TEXT NOT NULL,
    is_in_domain INTEGER,
    link_metadata TEXT,
    canonical_id TEXT,
    improved_text TEXT,
    FOREIGN KEY(source_doc_id) REFERENCES file_manifest(source_doc_id)
);
"""

CREATE_INDEXES = [
    "CREATE INDEX IF NOT EXISTS idx_manifest_path ON file_manifest(path);",
    "CREATE INDEX IF NOT EXISTS idx_manifest_hash ON file_manifest(content_hash);",
    "CREATE INDEX IF NOT EXISTS idx_chunks_source ON text_chunks(source_doc_id);",
    "CREATE INDEX IF NOT EXISTS idx_chunks_canonical ON text_chunks(canonical_id);",
    "CREATE INDEX IF NOT EXISTS idx_chunks_domain ON text_chunks(is_in_domain);"
]

DB_NAME = "knowledge_base.sqlite"

def get_db_path(base_dir: str = ".") -> str:
    return os.path.join(base_dir, DB_NAME)

def init_db(db_path: str):
    """Initialize the database with the schema."""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute(CREATE_MANIFEST_TABLE)
    cursor.execute(CREATE_CHUNKS_TABLE)
    
    for idx_sql in CREATE_INDEXES:
        cursor.execute(idx_sql)
        
    conn.commit()
    conn.close()
