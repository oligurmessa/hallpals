import sqlite3
import json
import numpy as np
from typing import List, Dict
from src.canonicalization.embedder import OpenAIEmbedder

class CanonicalizationManager:
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.embedder = OpenAIEmbedder() # Raises if no key
        self.stats = {
            "in_domain_total": 0,
            "newly_embedded": 0,
            "embedding_dim": self.embedder.DIMENSION,
            "est_tokens": 0,
            "est_cost": 0.0,
            "actual_tokens": 0,
            "canonical_groups": 0,
            "compression_ratio": 0.0
        }

    def _get_conn(self):
        return sqlite3.connect(self.db_path)

    def reset_mock_data(self):
        """Reset embeddings and canonical IDs to prepare for fresh run."""
        conn = self._get_conn()
        cursor = conn.cursor()
        print("Resetting previous embeddings and canonical IDs...")
        cursor.execute("DELETE FROM chunk_embeddings") # Clear all embeddings
        cursor.execute("UPDATE text_chunks SET canonical_id = NULL WHERE is_in_domain = 1")
        conn.commit()
        conn.close()

    def run_canonicalization(self):
        # 1. Reset
        self.reset_mock_data()
        
        conn = self._get_conn()
        cursor = conn.cursor()

        # 2. Select Target Chunks
        cursor.execute("SELECT chunk_id, normalized_text FROM text_chunks WHERE is_in_domain = 1")
        target_chunks = cursor.fetchall() # List of (id, text)
        self.stats["in_domain_total"] = len(target_chunks)
        
        if not target_chunks:
            print("No in-domain chunks found.")
            return self.stats

        # 3. Estimate
        total_chars = sum(len(row[1]) for row in target_chunks)
        est_tok, est_cost = self.embedder.estimate_cost(total_chars)
        self.stats["est_tokens"] = est_tok
        self.stats["est_cost"] = est_cost
        
        print(f"Targeting {len(target_chunks)} chunks for embedding.")
        print(f"Est Tokens: {est_tok}, Cost: ${est_cost:.5f}")

        # 4. Embed & Store
        batch_size = 50
        print("Embedding with OpenAI...")
        import datetime
        
        for i in range(0, len(target_chunks), batch_size):
            batch = target_chunks[i:i+batch_size]
            texts = [b[1] for b in batch]
            ids = [b[0] for b in batch]
            
            # API Call
            vectors, used_tokens = self.embedder.embed_batch(texts)
            
            self.stats["actual_tokens"] += used_tokens
            self.stats["newly_embedded"] += len(batch)
            
            # Insert
            now = datetime.datetime.now().timestamp()
            data_to_insert = []
            for j, vec in enumerate(vectors):
                data_to_insert.append((ids[j], json.dumps(vec), now))
            
            cursor.executemany("INSERT INTO chunk_embeddings (chunk_id, embedding_vector, created_ts) VALUES (?, ?, ?)", data_to_insert)
            conn.commit()
            print(f"Encoded batch {i//batch_size + 1}")

        # 5. Canonicalize (Greedy Clustering)
        print("Clustering via Cosine Similarity...")
        
        # Load logic
        cursor.execute("""
            SELECT c.chunk_id, c.normalized_text, e.embedding_vector 
            FROM text_chunks c 
            JOIN chunk_embeddings e ON c.chunk_id = e.chunk_id 
            WHERE c.is_in_domain = 1
        """)
        rows = cursor.fetchall()
        
        # Parse into list of dicts for sorting
        items = []
        for r in rows:
            items.append({
                "id": r[0],
                "len": len(r[1]),
                "vec": np.array(json.loads(r[2]), dtype=np.float32)
            })
            
        # Strategy: Sort by length descending to pick "best" canonical
        items.sort(key=lambda x: x["len"], reverse=True)
        
        assigned_canonical = {} # chunk_id -> canonical_id
        centroids = [] # list of {"id": canon_id, "vec": vector}
        
        SIM_THRESHOLD = 0.85 
        
        for item in items:
            cid = item["id"]
            vec = item["vec"]
            
            # Check similarity to existing centroids
            best_sim = -1.0
            best_canon_id = None
            
            for cent in centroids:
                # Cosine sim (vectors from OpenAI specific models are usually normalized, but safe to do dot product if magnitude is ~1)
                # Let's assume normalized or do manual norm.
                # OpenAI embed 3 large IS normalized.
                sim = np.dot(vec, cent["vec"])
                
                if sim > best_sim:
                    best_sim = sim
                    best_canon_id = cent["id"]
            
            if best_sim >= SIM_THRESHOLD:
                # Assign to group
                assigned_canonical[cid] = best_canon_id
            else:
                # Create New Group
                assigned_canonical[cid] = cid
                centroids.append({"id": cid, "vec": vec})
        
        # 6. Update DB
        print(f"Formed {len(centroids)} canonical groups.")
        self.stats["canonical_groups"] = len(centroids)
        
        ids_to_update = [(canon_id, chunk_id) for chunk_id, canon_id in assigned_canonical.items()]
        cursor.executemany("UPDATE text_chunks SET canonical_id = ? WHERE chunk_id = ?", ids_to_update)
        
        conn.commit()
        conn.close()
        
        if self.stats["canonical_groups"] > 0:
            self.stats["compression_ratio"] = self.stats["in_domain_total"] / self.stats["canonical_groups"]
            
        return self.stats

if __name__ == "__main__":
    from dotenv import load_dotenv
    load_dotenv() # Load .env if present
    
    db_path = "knowledge_base.sqlite"
    try:
        manager = CanonicalizationManager(db_path)
        stats = manager.run_canonicalization()
        print("Canonicalization Complete.")
        print(stats)
    except Exception as e:
        print(f"Failed: {e}")
