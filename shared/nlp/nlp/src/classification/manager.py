import sqlite3
import json
from src.classification.classifier import MockClassifier

class ClassificationManager:
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.classifier = MockClassifier()
        self.stats = {
            "processed": 0,
            "in_domain": 0,
            "out_of_domain": 0,
            "urls_found": 0,
            "article_links": 0,
            "resource_links": 0,
            "estimated_tokens": 0,
            "estimated_cost": 0.0
        }

    def _get_conn(self):
        return sqlite3.connect(self.db_path)

    def estimate_job(self):
        """
        Estimates total tokens and cost for pending chunks.
        """
        conn = self._get_conn()
        cursor = conn.cursor()
        cursor.execute("SELECT SUM(LENGTH(raw_text)) FROM text_chunks WHERE is_in_domain IS NULL")
        result = cursor.fetchone()
        total_chars = result[0] if result[0] else 0
        conn.close()

        total_tokens = total_chars // 4
        estimated_cost = (total_tokens / 1000) * self.classifier.cost_per_1k_tokens
        
        return total_tokens, estimated_cost

    def run_classification(self):
        conn = self._get_conn()
        cursor = conn.cursor()
        
        # Get chunks to process
        cursor.execute("SELECT chunk_id, raw_text FROM text_chunks WHERE is_in_domain IS NULL")
        chunks = cursor.fetchall() # List of (id, text)
        
        # Initial estimate update
        est_tokens, est_cost = self.estimate_job()
        self.stats["estimated_tokens"] = est_tokens
        self.stats["estimated_cost"] = est_cost
        
        print(f"Starting Classification on {len(chunks)} chunks.")
        print(f"Est Tokens: {est_tokens}, Cost: ${est_cost:.4f}")
        
        for chunk_id, raw_text in chunks:
            # Classify
            is_in_domain, links = self.classifier.process_chunk({"raw_text": raw_text})
            
            # Update Stats
            self.stats["processed"] += 1
            if is_in_domain:
                self.stats["in_domain"] += 1
            else:
                self.stats["out_of_domain"] += 1
                
            self.stats["urls_found"] += len(links)
            for link in links:
                if link['type'] == 'ARTICLE_TO_INGEST':
                    self.stats["article_links"] += 1
                else:
                    self.stats["resource_links"] += 1
            
            # Update DB
            cursor.execute("""
                UPDATE text_chunks 
                SET is_in_domain = ?, link_metadata = ? 
                WHERE chunk_id = ?
            """, (1 if is_in_domain else 0, json.dumps(links), chunk_id))
            
        conn.commit()
        conn.close()
        return self.stats

if __name__ == "__main__":
    import sys
    db_path = "knowledge_base.sqlite"
    manager = ClassificationManager(db_path)
    
    print("Estimating...")
    tokens, cost = manager.estimate_job()
    print(f"Estimate: {tokens} tokens, ${cost:.4f}")
    
    print("Running...")
    stats = manager.run_classification()
    print("Classification Complete.")
    print(stats)
