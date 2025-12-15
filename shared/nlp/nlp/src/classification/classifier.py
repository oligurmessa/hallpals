import re
import json
from typing import List, Dict, Tuple

class MockClassifier:
    """
    Simulates an LLM classifier using heuristics.
    """
    
    # Heuristics for "Residence Life Operations"
    DOMAIN_KEYWORDS = [
        "resident", "student", "dorm", "hall", "apartment", "housing", 
        "ra", "advisor", "emergency", "duty", "protocol", "incident", 
        "report", "policy", "procedure", "community", "programming",
        "lockout", "key", "check-in", "check-out", "roster"
    ]

    # Heuristics for "Article to Ingest" context
    INGEST_CONTEXT_KEYWORDS = [
        "read this", "review this", "reading", "article", 
        "please read", "assigned", "required", "full text"
    ]

    def __init__(self, cost_per_1k_tokens: float = 0.0005):
        self.cost_per_1k_tokens = cost_per_1k_tokens

    def estimate_tokens(self, text: str) -> int:
        return len(text) // 4

    def classify_domain(self, text: str) -> bool:
        """
        Returns True if text appears to be in-domain (Res Life Ops).
        """
        text_lower = text.lower()
        # Count keyword hits
        hits = sum(1 for kw in self.DOMAIN_KEYWORDS if kw in text_lower)
        # Threshold: meaningful presence
        return hits >= 1

    def extract_and_classify_links(self, text: str) -> List[Dict]:
        """
        Finds URLs and classifies them.
        """
        # Simple regex for URL
        url_pattern = r'https?://(?:[-\w.]|(?:%[\da-fA-F]{2}))+[/\w\.-]*'
        urls = list(set(re.findall(url_pattern, text))) # dedup urls in same chunk
        
        results = []
        text_lower = text.lower()
        
        # Check for ingest intent globally in the chunk for simpliciy, 
        # or proximity-based? The prompt implies "surrounding text".
        # For this mock, we'll check if ANY ingest keyword is present in the chunk.
        is_ingest_context = any(kw in text_lower for kw in self.INGEST_CONTEXT_KEYWORDS)
        
        for url in urls:
            link_type = "ARTICLE_TO_INGEST" if is_ingest_context else "RESOURCE_LINK"
            results.append({"url": url, "type": link_type})
            
        return results

    def process_chunk(self, chunk_data: Dict) -> Tuple[bool, List[Dict]]:
        """
        Runs both classifications.
        Returns (is_in_domain, link_metadata).
        """
        text = chunk_data.get('raw_text', "")
        is_in_domain = self.classify_domain(text)
        links = self.extract_and_classify_links(text)
        return is_in_domain, links
