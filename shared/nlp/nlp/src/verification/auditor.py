import os
import openai
from typing import List, Tuple, Dict
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

class ContentAuditor:
    MODEL = "gpt-5.1"
    # Pricing: Est $0.01 per 1k input/output (approx for top tier)
    PRICE_PER_1K_TOKENS = 0.010 

    SYSTEM_PROMPT = """You are comparing source documentation text fragments with their rewritten canonical summary.
Identify any missing facts, changed details, or dropped operational elements.
Be strict: list anything that is present in the originals but not clearly preserved in the rewritten text.
Return strictly one of:
"NO_OMISSIONS"
"HAS_OMISSIONS"
plus a brief machine-readable list of missing details when applicable.
Format:
STATUS: [NO_OMISSIONS | HAS_OMISSIONS]
NOTES: [Bullet points or "None"]"""

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
        stop=stop_after_attempt(10)
    )
    def audit_group(self, improved_text: str, source_texts: List[str]) -> Tuple[str, str, Dict]:
        """
        Compares improved_text vs source_texts.
        Returns (status, notes, usage_dict)
        """
        # Build prompt
        user_content = f"Improved Text:\n{improved_text}\n\nSource Chunks:\n"
        for i, text in enumerate(source_texts):
            user_content += f"{i+1}. {text}\n"

        if len(user_content) > 400000:
             return "ERROR", "Input too long", {"total_tokens": 0}

        response = self.client.chat.completions.create(
            model=self.MODEL,
            messages=[
                {"role": "system", "content": self.SYSTEM_PROMPT},
                {"role": "user", "content": user_content}
            ],
            temperature=0
        )
        
        content = response.choices[0].message.content
        usage = {
            "prompt_tokens": response.usage.prompt_tokens,
            "completion_tokens": response.usage.completion_tokens,
            "total_tokens": response.usage.total_tokens
        }
        
        # Parse output
        status = "UNKNOWN"
        notes = content
        
        lines = content.split('\n')
        for line in lines:
            if line.startswith("STATUS:"):
                status = line.replace("STATUS:", "").strip()
            if line.startswith("NOTES:"):
                # Notes might be multi-line, but typically follow
                pass
        
        # Fallback parsing if strict format missing (LLM might chat)
        if "NO_OMISSIONS" in content and "HAS_OMISSIONS" not in content:
            status = "NO_OMISSIONS"
        elif "HAS_OMISSIONS" in content:
            status = "HAS_OMISSIONS"
            
        return status, content, usage
