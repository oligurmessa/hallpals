import os
import openai
from typing import List, Tuple, Dict
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

class TopicClassifier:
    MODEL = "gpt-5.1"
    PRICE_PER_1K_TOKENS = 0.010 

    SYSTEM_PROMPT = """You are organizing a Residence Life Operations Knowledge Base.
Analyze the provided canonical text entry and assign the most appropriate TOPIC and SECTION.
Topics: Policies, Procedures, Training, Duty & On-Call, Incidents, Housing, Student Conduct, Safety, Facilities, Move-in/out, Emergencies, General.
Return strictly in this format:
TOPIC: <topic_name>
SECTION: <section_name>"""

    def __init__(self):
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("OPENAI_API_KEY is not set.")
        self.client = openai.OpenAI(api_key=api_key)

    def estimate_cost(self, total_chars: int) -> Tuple[int, float]:
        tokens = total_chars // 4
        cost = (tokens / 1000) * self.PRICE_PER_1K_TOKENS
        return tokens, cost

    @retry(
        retry=retry_if_exception_type((openai.RateLimitError, openai.APIConnectionError, openai.APITimeoutError)),
        wait=wait_exponential(multiplier=1, min=2, max=60),
        stop=stop_after_attempt(5)
    )
    def classify_entry(self, text: str) -> Tuple[str, str, Dict]:
        """
        Returns (topic, section, usage).
        """
        # Truncate text if too long for classification context (rare for canonical, but safe)
        if len(text) > 10000:
            text = text[:10000] + "... (truncated)"
            
        try:
            response = self.client.chat.completions.create(
                model=self.MODEL,
                messages=[
                    {"role": "system", "content": self.SYSTEM_PROMPT},
                    {"role": "user", "content": f"Entry:\n{text}"}
                ],
                temperature=0
            )
            
            content = response.choices[0].message.content
            usage = {
                "prompt_tokens": response.usage.prompt_tokens,
                "completion_tokens": response.usage.completion_tokens,
                "total_tokens": response.usage.total_tokens
            }
            
            topic = "Unclassified"
            section = "General"
            
            lines = content.split('\n')
            for line in lines:
                if line.startswith("TOPIC:"):
                    topic = line.replace("TOPIC:", "").strip()
                if line.startswith("SECTION:"):
                    section = line.replace("SECTION:", "").strip()
            
            return topic, section, usage
            
        except Exception as e:
            # Fallback
            print(f"Classifier Error: {e}")
            return "Unclassified", "Error", {}
