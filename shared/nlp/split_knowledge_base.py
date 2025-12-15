import json
import os
import re

def sanitize_filename(name):
    """Sanitize the topic name to be safe for filenames."""
    # Replace invalid characters with underscores
    return re.sub(r'[<>:"/\\|?*]', '_', name).strip().replace(' ', '_').lower()

def split_knowledge_base(input_file, output_dir):
    """Split the knowledge base JSON into topic-specific files."""
    try:
        with open(input_file, 'r') as f:
            data = json.load(f)
        
        if not isinstance(data, list):
            print("Error: Input JSON must be a list of objects.")
            return

        # Group data by topic
        topics = {}
        for item in data:
            topic = item.get("topic", "Unknown")
            if topic not in topics:
                topics[topic] = []
            topics[topic].append(item)
        
        # Ensure output directory exists
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)
            print(f"Created directory: {output_dir}")
        
        # Write each topic to a separate file
        for topic, items in topics.items():
            filename = f"{sanitize_filename(topic)}.json"
            file_path = os.path.join(output_dir, filename)
            
            with open(file_path, 'w') as f:
                json.dump(items, f, indent=2)
            
            print(f"Written {len(items)} items to {filename}")

        print(f"Successfully split {len(data)} items into {len(topics)} topic files.")
        
    except FileNotFoundError:
        print(f"Error: File not found: {input_file}")
    except json.JSONDecodeError:
        print(f"Error: Invalid JSON in {input_file}")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    INPUT_FILE = os.path.join(BASE_DIR, "knowledge_base.json")
    OUTPUT_DIR = os.path.join(BASE_DIR, "knowledge_base_topics")
    
    print(f"Processing {INPUT_FILE}...")
    split_knowledge_base(INPUT_FILE, OUTPUT_DIR)
