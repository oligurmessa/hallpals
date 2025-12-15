import sqlite3
import datetime
from typing import List, Dict
from concurrent.futures import ThreadPoolExecutor, as_completed
from src.verification.auditor import ContentAuditor

class VerificationManager:
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.auditor = ContentAuditor()
        self.stats = {
            "total_in_domain": 0,
            "with_improved": 0,
            "coverage_pass": False,
            "groups_audited": 0,
            "groups_with_omissions": 0,
            "est_tokens": 0,
            "est_cost": 0.0,
            "actual_total_tokens": 0,
            "actual_cost": 0.0
        }

    def _get_conn(self):
        return sqlite3.connect(self.db_path)

    def _ensure_tables(self):
        conn = self._get_conn()
        cursor = conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS verification_results (
                canonical_id TEXT PRIMARY KEY,
                status TEXT, -- NO_OMISSIONS, HAS_OMISSIONS
                notes TEXT,
                audit_ts REAL,
                FOREIGN KEY(canonical_id) REFERENCES text_chunks(chunk_id)
            )
        """)
        conn.commit()
        conn.close()

    def run_coverage_check(self) -> bool:
        conn = self._get_conn()
        cursor = conn.cursor()
        
        # Count total in-domain chunks
        cursor.execute("SELECT COUNT(*) FROM text_chunks WHERE is_in_domain = 1")
        total = cursor.fetchone()[0]
        self.stats["total_in_domain"] = total
        
        # Count in-domain that have improved_text linked
        # "Every in-domain TextChunk is mapped to a canonical group with a non-null improved_text"
        # Since we stored improved_text on the canonical leader chunk, we join via canonical_id
        cursor.execute("""
            SELECT COUNT(*) 
            FROM text_chunks c
            JOIN text_chunks leader ON c.canonical_id = leader.chunk_id
            WHERE c.is_in_domain = 1 AND leader.improved_text IS NOT NULL
        """)
        covered = cursor.fetchone()[0]
        self.stats["with_improved"] = covered
        
        passed = (total > 0) and (total == covered)
        self.stats["coverage_pass"] = passed
        conn.close()
        return passed

    def run_verification(self):
        self._ensure_tables()
        
        # 1. Coverage Check
        print("Running Coverage Check...")
        if not self.run_coverage_check():
            print(f"Coverage FAILED: {self.stats['with_improved']}/{self.stats['total_in_domain']}")
            # Proceed anyway? Prompt says "This phase only evaluates".
        else:
            print("Coverage PASSED.")

        conn = self._get_conn()
        cursor = conn.cursor()

        # 2. Select Groups
        cursor.execute("""
            SELECT canonical_id, improved_text 
            FROM text_chunks 
            WHERE is_in_domain = 1 AND improved_text IS NOT NULL
            GROUP BY canonical_id
        """)
        groups_raw = cursor.fetchall() # List of (canon_id, improved_text)
        
        # Need source texts for each
        group_data = [] # List of tuples (cid, improved, [sources])
        total_chars = 0
        
        print("Preparing data...")
        for cid, improved in groups_raw:
            cursor.execute("SELECT normalized_text FROM text_chunks WHERE canonical_id = ? AND is_in_domain = 1 ORDER BY chunk_id", (cid,))
            sources = [r[0] for r in cursor.fetchall()]
            group_data.append((cid, improved, sources))
            total_chars += len(improved) + sum(len(s) for s in sources)
            
        # Estimate
        est_tok, est_cost = self.auditor.estimate_cost(total_chars)
        self.stats["est_tokens"] = est_tok
        self.stats["est_cost"] = est_cost
        print(f"Auditing {len(group_data)} groups. Est Cost: ${est_cost:.4f}")
        
        # 3. Parallel Audit
        print("Starting LLM Audit...")
        
        def process_audit(item):
            cid, imp, srcs = item
            try:
                status, notes, usage = self.auditor.audit_group(imp, srcs)
                return cid, status, notes, usage
            except Exception as e:
                return cid, "ERROR", str(e), {}

        finished_count = 0
        
        # Use high threads for checking (5)
        with ThreadPoolExecutor(max_workers=5) as executor:
            futures = {executor.submit(process_audit, item): item[0] for item in group_data}
            
            for future in as_completed(futures):
                cid, status, notes, usage = future.result()
                
                # Store results
                now = datetime.datetime.now().timestamp()
                cursor.execute("INSERT OR REPLACE INTO verification_results (canonical_id, status, notes, audit_ts) VALUES (?, ?, ?, ?)", 
                               (cid, status, notes, now))
                
                self.stats["groups_audited"] += 1
                if status == "HAS_OMISSIONS":
                    self.stats["groups_with_omissions"] += 1
                
                self.stats["actual_total_tokens"] += usage.get("total_tokens", 0)
                
                finished_count += 1
                if finished_count % 20 == 0:
                    conn.commit()
                    print(f"Audited {finished_count}/{len(group_data)}...")
        
        conn.commit()
        
        # Actual Cost
        self.stats["actual_cost"] = (self.stats["actual_total_tokens"] / 1000) * self.auditor.PRICE_PER_1K_TOKENS
        
        conn.close()
        return self.stats

if __name__ == "__main__":
    from dotenv import load_dotenv
    load_dotenv()
    db_path = "knowledge_base.sqlite"
    manager = VerificationManager(db_path)
    stats = manager.run_verification()
    print("Verification Complete.")
    print(stats)
