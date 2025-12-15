import sqlite3
import datetime
from typing import List, Dict
from src.extraction.extractors import get_extractor, AudioTranscriber

class ExtractionManager:
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.audio_stats = {'files': 0, 'minutes': 0.0, 'cost': 0.0}
        self.processed_stats = {} # type -> count

    def _get_conn(self):
        return sqlite3.connect(self.db_path)

    def reset_unchanged_to_new(self):
        """Helper to force processing of UNCHANGED files if they have no chunks."""
        conn = self._get_conn()
        cursor = conn.cursor()
        # Find files that are UNCHANGED but have last_processed_ts is NULL (never processed)
        cursor.execute("""
            UPDATE file_manifest
            SET processing_status = 'NEW'
            WHERE processing_status = 'UNCHANGED' AND last_processed_ts IS NULL
        """)
        count = cursor.rowcount
        conn.commit()
        conn.close()
        return count

    def process_pending(self):
        conn = self._get_conn()
        cursor = conn.cursor()
        
        # Select NEW or CHANGED
        cursor.execute("""
            SELECT source_doc_id, path, source_type 
            FROM file_manifest 
            WHERE processing_status IN ('NEW', 'CHANGED')
        """)
        files = cursor.fetchall()
        
        print(f"Processing {len(files)} files...")
        
        for row in files:
            doc_id, path, source_type = row
            extractor = get_extractor(source_type)
            
            if not extractor:
                print(f"No extractor for {source_type} ({path})")
                continue

            try:
                # Extract
                chunks = extractor.extract(path, doc_id)
                
                # Check for empty (maybe valid for image?)
                if not chunks:
                    print(f"No chunks for {path}")
                    # Still mark as extracted? Or Warning?
                    # Proceeding to update status anyway.

                # Insert chunks
                for chunk in chunks:
                    cursor.execute("""
                        INSERT INTO text_chunks (
                            chunk_id, source_doc_id, location_metadata, raw_text, 
                            normalized_text, is_in_domain, link_metadata, 
                            canonical_id, improved_text
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, (
                        chunk['chunk_id'], chunk['source_doc_id'], chunk['location_metadata'],
                        chunk['raw_text'], chunk['normalized_text'], chunk['is_in_domain'],
                        chunk['link_metadata'], chunk['chunk_id'], chunk['improved_text']
                    ))
                
                # Update Manifest
                now = datetime.datetime.now().timestamp()
                cursor.execute("""
                    UPDATE file_manifest 
                    SET processing_status = 'EXTRACTED', last_processed_ts = ?
                    WHERE source_doc_id = ?
                """, (now, doc_id))
                
                # Stats
                self.processed_stats[source_type] = self.processed_stats.get(source_type, 0) + 1
                if isinstance(extractor, AudioTranscriber):
                    self.audio_stats['files'] += 1
                    # AudioTranscriber accumulates internally, but we instantiated new one each time in get_extractor 
                    # This is a bug in my simple get_extractor factory design if I want global stats.
                    # Fix: Grab stats from the instance
                    self.audio_stats['minutes'] += extractor.accumulated_minutes
                    self.audio_stats['cost'] += extractor.accumulated_cost

                conn.commit()

            except Exception as e:
                print(f"Failed to process {path}: {e}")
                cursor.execute("""
                    UPDATE file_manifest 
                    SET processing_status = 'ERROR', error_message = ?
                    WHERE source_doc_id = ?
                """, (str(e), doc_id))
                conn.commit()

        conn.close()
        return self.processed_stats, self.audio_stats

if __name__ == "__main__":
    import sys
    db_path = "knowledge_base.sqlite"
    manager = ExtractionManager(db_path)
    
    # 1. Reset
    reset_count = manager.reset_unchanged_to_new()
    print(f"Reset {reset_count} files to NEW.")
    
    # 2. Process
    stats, audio_stats = manager.process_pending()
    print("Processing Complete.")
    print("Stats:", stats)
    print("Audio Stats:", audio_stats)
