import os
import sys

# Ensure src is in path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.data.schema import init_db, get_db_path
from src.ingestion.manifest import ManifestManager

def main():
    root_dir = os.path.abspath("documents")
    if not os.path.exists(root_dir):
        # Create a dummy documents folder if it doesn't exist for testing
        os.makedirs(root_dir)
        print(f"Created {root_dir}")

    db_path = get_db_path()
    print(f"Database: {db_path}")
    
    # 1. Init DB
    init_db(db_path)
    print("Database initialized.")
    
    # 2. Run Manifest
    manager = ManifestManager(db_path)
    print(f"Scanning {root_dir}...")
    stats = manager.scan_and_update(root_dir)
    print("Manifest Stats:", stats)
    
    # 3. Check Pending
    pending = manager.get_pending_files()
    print(f"Pending Files: {len(pending)}")
    for p in pending[:5]:
        print(f" - {p[1]} ({p[2]})")

if __name__ == "__main__":
    main()
