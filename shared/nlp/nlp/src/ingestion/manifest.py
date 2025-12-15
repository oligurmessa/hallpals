import os
import hashlib
import uuid
import sqlite3
import datetime
from typing import List, Tuple, Optional

# Extension mapping
EXTENSION_MAP = {
    '.pdf': 'PDF',
    '.ppt': 'PPT',
    '.pptx': 'PPT',
    '.mp3': 'AUDIO',
    '.wav': 'AUDIO',
    '.m4a': 'AUDIO',
    '.mp4': 'AUDIO',
    '.png': 'IMAGE',
    '.jpg': 'IMAGE',
    '.jpeg': 'IMAGE',
    '.txt': 'TEXT',
    '.md': 'TEXT'
}

class ManifestManager:
    def __init__(self, db_path: str):
        self.db_path = db_path

    def _compute_hash(self, file_path: str) -> str:
        """Computes SHA-256 hash of the file."""
        sha256_hash = hashlib.sha256()
        try:
            with open(file_path, "rb") as f:
                # Read in 64k chunks
                for byte_block in iter(lambda: f.read(65536), b""):
                    sha256_hash.update(byte_block)
            return sha256_hash.hexdigest()
        except IOError:
            return ""

    def _get_connection(self):
        return sqlite3.connect(self.db_path)

    def scan_and_update(self, root_directory: str) -> dict:
        """
        Scans directory, updates manifest.
        Returns stats: {'new': int, 'changed': int, 'unchanged': int, 'error': int}
        """
        conn = self._get_connection()
        cursor = conn.cursor()
        
        stats = {'new': 0, 'changed': 0, 'unchanged': 0, 'error': 0}
        
        # Get existing manifest entries {path: (source_doc_id, content_hash)}
        cursor.execute("SELECT path, source_doc_id, content_hash FROM file_manifest")
        existing_files = {row[0]: {'id': row[1], 'hash': row[2]} for row in cursor.fetchall()}
        
        found_paths = set()

        for root, _, files in os.walk(root_directory):
            for file in files:
                ext = os.path.splitext(file)[1].lower()
                if ext not in EXTENSION_MAP:
                    continue
                
                source_type = EXTENSION_MAP[ext]
                abs_path = os.path.abspath(os.path.join(root, file))
                found_paths.add(abs_path)
                
                current_hash = self._compute_hash(abs_path)
                if not current_hash:
                    stats['error'] += 1
                    continue
                
                if abs_path in existing_files:
                    # Check for change
                    entry = existing_files[abs_path]
                    if entry['hash'] != current_hash:
                        # Update -> CHANGED
                        cursor.execute("""
                            UPDATE file_manifest 
                            SET content_hash = ?, processing_status = 'CHANGED', last_processed_ts = NULL 
                            WHERE source_doc_id = ?
                        """, (current_hash, entry['id']))
                        stats['changed'] += 1
                    else:
                        # MATCH -> UNCHANGED
                        # We explicitly set status to UNCHANGED to indicate it was verified in this run
                        cursor.execute("""
                            UPDATE file_manifest 
                            SET processing_status = 'UNCHANGED' 
                            WHERE source_doc_id = ?
                        """, (entry['id'],))
                        stats['unchanged'] += 1
                else:
                    # Insert -> NEW
                    new_id = str(uuid.uuid4())
                    cursor.execute("""
                        INSERT INTO file_manifest (source_doc_id, path, source_type, content_hash, processing_status)
                        VALUES (?, ?, ?, ?, 'NEW')
                    """, (new_id, abs_path, source_type, current_hash))
                    stats['new'] += 1
        
        conn.commit()
        conn.close()
        return stats

    def get_pending_files(self, limit: int = 100) -> List[Tuple]:
        """Returns list of (source_doc_id, path, source_type) for files needing processing."""
        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT source_doc_id, path, source_type 
            FROM file_manifest 
            WHERE processing_status IN ('NEW', 'ERROR')
            LIMIT ?
        """, (limit,))
        results = cursor.fetchall()
        conn.close()
        return results

    def update_status(self, source_doc_id: str, status: str, error_msg: Optional[str] = None):
        """Update status of a file."""
        conn = self._get_connection()
        cursor = conn.cursor()
        now = datetime.datetime.now().timestamp()
        cursor.execute("""
            UPDATE file_manifest 
            SET processing_status = ?, last_processed_ts = ?, error_message = ? 
            WHERE source_doc_id = ?
        """, (status, now, error_msg, source_doc_id))
        conn.commit()
        conn.close()

if __name__ == "__main__":
    # Test run
    import sys
    db_path = "knowledge_base.sqlite"
    if len(sys.argv) > 1:
        target_dir = sys.argv[1]
    else:
        target_dir = "documents" # default

    manager = ManifestManager(db_path)
    print(f"Scanning {target_dir}...")
    stats = manager.scan_and_update(target_dir)
    print("Stats:", stats)
    
    pending = manager.get_pending_files()
    print(f"Pending files: {len(pending)}")
