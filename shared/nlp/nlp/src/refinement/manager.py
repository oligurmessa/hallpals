import sqlite3
import datetime
from typing import List, Dict
from src.refinement.rewriter import Rewriter

class RefinementManager:
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.rewriter = Rewriter()
        self.stats = {
            "groups_targeted": 0,
            "groups_rewritten": 0,
            "groups_skipped": 0,
            "est_tokens": 0,
            "est_cost": 0.0,
            "actual_prompt_tokens": 0,
            "actual_completion_tokens": 0,
            "actual_total_tokens": 0,
            "actual_cost": 0.0
        }

    def _get_conn(self):
        return sqlite3.connect(self.db_path)

    def run_refinement(self):
        conn = self._get_conn()
        cursor = conn.cursor()

        # 1. Select Canonical Groups (with at least 1 in-domain chunk)
        # We need distinct canonical_ids where is_in_domain=1
        cursor.execute("SELECT DISTINCT canonical_id FROM text_chunks WHERE is_in_domain = 1 AND canonical_id IS NOT NULL")
        groups = [row[0] for row in cursor.fetchall()]
        
        self.stats["groups_targeted"] = len(groups)
        print(f"Targeting {len(groups)} canonical groups.")

        # 2. Pre-Fetch & Estimate
        group_data = {} # canon_id -> [texts]
        total_chars_source = 0
        
        for canon_id in groups:
            cursor.execute("SELECT normalized_text FROM text_chunks WHERE canonical_id = ? AND is_in_domain = 1 ORDER BY chunk_id", (canon_id,))
            texts = [r[0] for r in cursor.fetchall()]
            group_data[canon_id] = texts
            total_chars_source += sum(len(t) for t in texts)
        
        est_tok, est_cost = self.rewriter.estimate_cost(total_chars_source)
        self.stats["est_tokens"] = est_tok
        self.stats["est_cost"] = est_cost
        
        print(f"Est Tokens: {est_tok}, Est Cost (Input Only): ${est_cost:.4f}")

        # 3. Rewrite Loop (Parallel)
        print("Starting Rewrites (Parallel, Robust)...")
        from concurrent.futures import ThreadPoolExecutor, as_completed
        
        # Check which groups already done?
        cursor.execute("SELECT chunk_id FROM text_chunks WHERE improved_text IS NOT NULL")
        completed_ids = set(row[0] for row in cursor.fetchall())
        
        pending_groups = [g for g in groups if g not in completed_ids]
        print(f"Already done: {len(completed_ids)}. Pending: {len(pending_groups)}")

        # Helper for threaded worker
        def process_group(canon_id):
            texts = group_data[canon_id]
            if not texts:
                return None
            try:
                improved, usage = self.rewriter.rewrite_group(texts)
                if improved.startswith("[ERROR"):
                    print(f"Skipped {canon_id}: Too long.")
                    return ("SKIPPED", canon_id, None, None)
                return ("SUCCESS", canon_id, improved, usage)
            except Exception as e:
                print(f"Error on {canon_id}: {e}")
                return ("ERROR", canon_id, str(e), None)

        finished_count = len(completed_ids)
        
        # Using 3 workers to respect 30k TPM rate limit
        with ThreadPoolExecutor(max_workers=3) as executor:
            futures = {executor.submit(process_group, cid): cid for cid in pending_groups}
            
            for future in as_completed(futures):
                status, cid, result, usage = future.result()
                
                if status == "SUCCESS":
                    # Update DB (SQLite isn't thread-safe for write from threads, so we write here in main thread)
                    improved_text = result
                    cursor.execute("UPDATE text_chunks SET improved_text = ? WHERE chunk_id = ?", (improved_text, cid))
                    
                    self.stats["groups_rewritten"] += 1
                    self.stats["actual_prompt_tokens"] += usage.get("prompt_tokens", 0)
                    self.stats["actual_completion_tokens"] += usage.get("completion_tokens", 0)
                    self.stats["actual_total_tokens"] += usage.get("total_tokens", 0)
                
                elif status == "SKIPPED":
                    self.stats["groups_skipped"] += 1
                elif status == "ERROR":
                    self.stats["groups_skipped"] += 1

                finished_count += 1
                if finished_count % 10 == 0:
                    conn.commit()
                    print(f"Processed {finished_count}/{len(groups)}...")
        
        conn.commit()

        # Calc actual cost
        c_in = (self.stats["actual_prompt_tokens"] / 1_000_000) * 2.50
        c_out = (self.stats["actual_completion_tokens"] / 1_000_000) * 10.00
        self.stats["actual_cost"] = c_in + c_out
        
        conn.close()
        return self.stats

if __name__ == "__main__":
    from dotenv import load_dotenv
    load_dotenv()
    db_path = "knowledge_base.sqlite"
    manager = RefinementManager(db_path)
    stats = manager.run_refinement()
    print("Refinement Complete.")
    print(stats)
