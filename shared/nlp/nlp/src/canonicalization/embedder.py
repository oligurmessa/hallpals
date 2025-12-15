import os
import time
from typing import List, Tuple
import openai

class OpenAIEmbedder:
    """
    Real 'text-embedding-3-large' integration.
    """
    DIMENSION = 3072
    PRICE_PER_1K_TOKENS = 0.00013 

    def __init__(self):
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("OPENAI_API_KEY is not set.")
        # Minimal init
        self.client = openai.OpenAI(api_key=api_key)

    def estimate_cost(self, total_chars: int) -> Tuple[int, float]:
        tokens = total_chars // 4
        cost = (tokens / 1000) * self.PRICE_PER_1K_TOKENS
        return tokens, cost

    def embed_batch(self, texts: List[str]) -> Tuple[List[List[float]], int]:
        """
        Returns list of vectors and actual token usage.
        """
        # Ensure texts not empty
        if not texts:
            return [], 0
            
        try:
            response = self.client.embeddings.create(
                input=texts,
                model="text-embedding-3-large",
                encoding_format="float"
            )
            
            # Extract vectors in order
            data = sorted(response.data, key=lambda x: x.index)
            vectors = [d.embedding for d in data]
            usage = response.usage.total_tokens
            
            return vectors, usage
            
        except Exception as e:
            print(f"OpenAI API Error: {e}")
            raise e
