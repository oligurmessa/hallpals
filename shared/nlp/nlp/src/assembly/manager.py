import sqlite3
import json
import os
from typing import List, Dict
from concurrent.futures import ThreadPoolExecutor, as_completed
from src.assembly.classifier import TopicClassifier

class AssemblyManager:
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.classifier = TopicClassifier()
        self.stats = {
            "entries_total": 0,
            "classified_new": 0,
            "kb_entries_generated": 0,
            "actual_cost": 0.0,
            "topics_found": set()
        }

    def _get_conn(self):
        return sqlite3.connect(self.db_path)

    def _ensure_tables(self):
        conn = self._get_conn()
        cursor = conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS kb_metadata (
                canonical_id TEXT PRIMARY KEY,
                topic TEXT,
                section TEXT,
                FOREIGN KEY(canonical_id) REFERENCES text_chunks(chunk_id)
            )
        """)
        conn.commit()
        conn.close()

    def run_assembly(self):
        self._ensure_tables()
        conn = self._get_conn()
        cursor = conn.cursor()

        # 1. Get Canonical Entries
        cursor.execute("""
            SELECT chunk_id, improved_text 
            FROM text_chunks 
            WHERE is_in_domain = 1 AND improved_text IS NOT NULL
            GROUP BY chunk_id -- Ensure unique canonical entries (if they are chunks)
        """)
        # Actually canonical_ids are chunk_ids.
        # But wait, improved_text is on the canonical chunk.
        # Let's select all chunks that have improved_text (these ARE the canonical representatives).
        cursor.execute("SELECT chunk_id, improved_text FROM text_chunks WHERE improved_text IS NOT NULL")
        entries = cursor.fetchall()
        self.stats["entries_total"] = len(entries)
        
        print(f"Found {len(entries)} canonical entries for assembly.")
        
        # 2. Classify (if missing)
        # Check existing
        cursor.execute("SELECT canonical_id FROM kb_metadata")
        existing_ids = set(row[0] for row in cursor.fetchall())
        
        pending_entries = [e for e in entries if e[0] not in existing_ids]
        print(f"Pending classification: {len(pending_entries)}")
        
        if pending_entries:
            print("Classifying...")
            total_tokens_used = 0
            
            def process_classification(item):
                cid, text = item
                topic, section, usage = self.classifier.classify_entry(text)
                return cid, topic, section, usage

            with ThreadPoolExecutor(max_workers=5) as executor:
                futures = {executor.submit(process_classification, e): e[0] for e in pending_entries}
                
                completed_count = 0
                for future in as_completed(futures):
                    cid, topic, section, usage = future.result()
                    
                    cursor.execute("INSERT OR REPLACE INTO kb_metadata (canonical_id, topic, section) VALUES (?, ?, ?)", 
                                   (cid, topic, section))
                    
                    total_tokens_used += usage.get("total_tokens", 0)
                    self.stats["classified_new"] += 1
                    
                    completed_count += 1
                    if completed_count % 20 == 0:
                        conn.commit()
                        print(f"Classified {completed_count}/{len(pending_entries)}...")
            
            conn.commit()
            cost = (total_tokens_used / 1000) * self.classifier.PRICE_PER_1K_TOKENS
            self.stats["actual_cost"] += cost
            print(f"Classification Cost: ${cost:.4f}")

        # 3. Build Data Structures
        print("Building KB...")
        kb_index = {}
        kb_full = []
        traceability = []
        
        # Join data
        cursor.execute("""
            SELECT m.canonical_id, m.topic, m.section, c.improved_text
            FROM kb_metadata m
            JOIN text_chunks c ON m.canonical_id = c.chunk_id
        """)
        rows = cursor.fetchall()
        
        for cid, topic, section, text in rows:
            self.stats["topics_found"].add(topic)
            
            # Add to Index
            if topic not in kb_index:
                kb_index[topic] = {}
            if section not in kb_index[topic]:
                kb_index[topic][section] = []
            kb_index[topic][section].append(cid)
            
            # Add to Full KB
            # Get Sources
            cursor.execute("""
                SELECT c.source_doc_id, f.path, c.location_metadata
                FROM text_chunks c
                JOIN file_manifest f ON c.source_doc_id = f.source_doc_id
                WHERE c.canonical_id = ?
            """, (cid,))
            sources_raw = cursor.fetchall()
            sources = []
            for did, path, loc in sources_raw:
                sources.append({"source_doc_id": did, "path": path, "location": loc})
            
            entry = {
                "canonical_id": cid,
                "topic": topic,
                "section": section,
                "text": text,
                "sources": sources
            }
            kb_full.append(entry)
            
            # Traceability
            traceability.append({
                "id": cid,
                "topic": topic, 
                "section": section,
                "sources_count": len(sources),
                "source_files": [s["path"] for s in sources]
            })
            
        self.stats["kb_entries_generated"] = len(kb_full)
        
        # 4. Write Files
        print("Writing artifacts...")
        with open("knowledge_index.json", "w") as f:
            json.dump(kb_index, f, indent=2)
            
        with open("knowledge_base.json", "w") as f:
            json.dump(kb_full, f, indent=2)
            
        # Markdown Handbook
        with open("knowledge_base.md", "w") as f:
            f.write("# Residence Life Operations Knowledge Base\n\n")
            for topic in sorted(kb_index.keys()):
                f.write(f"## {topic}\n")
                for section in sorted(kb_index[topic].keys()):
                    f.write(f"### {section}\n")
                    # Get entries
                    cids = kb_index[topic][section]
                    for cid in cids:
                        # Find entry data (inefficient list scan but fine for 437 items)
                        entry_data = next(e for e in kb_full if e["canonical_id"] == cid)
                        f.write(f"{entry_data['text']}\n\n")
                        f.write("**Sources:**\n")
                        for s in entry_data["sources"]:
                           f.write(f"- `{os.path.basename(s['path'])}`\n")
                        f.write("\n---\n\n")
        
        # Traceability Report
        with open("traceability_report.md", "w") as f:
            f.write("# Traceability Report\n\n")
            f.write("| Canonical ID | Topic | Section | Source Count | Files |\n")
            f.write("|--------------|-------|---------|--------------|-------|\n")
            for t in traceability:
                files_str = "<br>".join([os.path.basename(p) for p in t["source_files"][:5]])
                if len(t["source_files"]) > 5:
                    files_str += "<br>..."
                f.write(f"| {t['id']} | {t['topic']} | {t['section']} | {t['sources_count']} | {files_str} |\n")

        conn.close()
        # Convert set to list for printing
        self.stats["topics_found"] = list(self.stats["topics_found"])
        return self.stats

if __name__ == "__main__":
    from dotenv import load_dotenv
    load_dotenv()
    db_path = "knowledge_base.sqlite"
    manager = AssemblyManager(db_path)
    stats = manager.run_assembly()
    print("Assembly Complete.")
    print(stats)
