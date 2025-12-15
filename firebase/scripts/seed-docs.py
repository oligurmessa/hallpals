#!/usr/bin/env python3
"""
Seed script to populate Firestore /docs collection from knowledge_base.json

Usage:
  cd /Users/oligurmessa/hallpals/firebase
  python3 scripts/seed-docs.py

Requires: pip install firebase-admin
"""

import json
import os
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore

# Topic slugs matching KBTopic.slug in iOS
TOPIC_SLUGS = {
    "Duty & On-Call": "duty_&_on-call",
    "Emergencies": "emergencies",
    "Facilities": "facilities",
    "General": "general",
    "Housing": "housing",
    "Incidents": "incidents",
    "Move-in/out": "move-in_out",
    "Policies": "policies",
    "Procedures": "procedures",
    "Safety": "safety",
    "Student Conduct": "student_conduct",
    "Training": "training"
}

TOPIC_INFO = {
    "duty_&_on-call": {"title": "Duty & On-Call", "category": "operations"},
    "emergencies": {"title": "Emergencies", "category": "safety"},
    "facilities": {"title": "Facilities", "category": "operations"},
    "general": {"title": "General", "category": "general"},
    "housing": {"title": "Housing", "category": "housing"},
    "incidents": {"title": "Incidents", "category": "operations"},
    "move-in_out": {"title": "Move-in/out", "category": "housing"},
    "policies": {"title": "Policies", "category": "compliance"},
    "procedures": {"title": "Procedures", "category": "operations"},
    "safety": {"title": "Safety", "category": "safety"},
    "student_conduct": {"title": "Student Conduct", "category": "compliance"},
    "training": {"title": "Training", "category": "training"}
}

def main():
    script_dir = Path(__file__).parent

    # Check for service account
    sa_paths = [
        script_dir / "../serviceAccount.json",
        script_dir / "../service-account.json",
    ]

    sa_path = None
    for p in sa_paths:
        if p.exists():
            sa_path = p
            print(f"Using service account from: {sa_path}")
            break

    # Initialize Firebase
    if sa_path:
        cred = credentials.Certificate(str(sa_path))
        firebase_admin.initialize_app(cred, {"projectId": "hallpals"})
    else:
        # Use application default credentials
        print("No service account found, using Application Default Credentials")
        firebase_admin.initialize_app(options={"projectId": "hallpals"})

    db = firestore.client()

    # Load knowledge base
    kb_path = script_dir / "../../apps/ios/HallHub/HallHub/Features/Resources/knowledge_base.json"
    if not kb_path.exists():
        print(f"knowledge_base.json not found at: {kb_path}")
        return 1

    with open(kb_path, "r") as f:
        kb_data = json.load(f)

    print(f"Loaded {len(kb_data)} entries from knowledge_base.json\n")

    # Group entries by topic
    entries_by_topic = {}
    for entry in kb_data:
        topic = entry["topic"]
        if topic not in entries_by_topic:
            entries_by_topic[topic] = []
        entries_by_topic[topic].append(entry)

    print(f"Topics found: {list(entries_by_topic.keys())}\n")

    # Create doc for each topic
    for topic_name, entries in entries_by_topic.items():
        slug = TOPIC_SLUGS.get(topic_name)
        if not slug:
            print(f"⚠️  Unknown topic '{topic_name}', skipping...")
            continue

        info = TOPIC_INFO[slug]
        print(f"📝 Creating /docs/{slug} with {len(entries)} entries...")

        # Create the doc metadata
        doc_ref = db.collection("docs").document(slug)
        doc_ref.set({
            "title": info["title"],
            "slug": slug,
            "category": info["category"],
            "isPublished": True,
            "createdAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
            "entryCount": len(entries)
        })

        # Create entries subcollection
        entries_ref = doc_ref.collection("entries")

        order = 0
        for entry in entries:
            order += 1
            entry_id = entry.get("canonical_id") or f"entry_{order}"

            entries_ref.document(entry_id).set({
                "order": order,
                "topic": topic_name,
                "section": entry.get("section", "General"),
                "text": entry["text"],
                "sources": entry.get("sources", []),
                "createdAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP
            })

        print(f"   ✅ Created {len(entries)} entries")

    # Ensure all 12 topics exist (even if empty)
    for slug, info in TOPIC_INFO.items():
        doc_ref = db.collection("docs").document(slug)
        doc = doc_ref.get()

        if not doc.exists:
            print(f"📝 Creating empty /docs/{slug}...")
            doc_ref.set({
                "title": info["title"],
                "slug": slug,
                "category": info["category"],
                "isPublished": True,
                "createdAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "entryCount": 0
            })
            print(f"   ✅ Created (empty)")

    print("\n✅ Seed complete!")
    return 0

if __name__ == "__main__":
    exit(main())
