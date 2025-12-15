import os
import openai
from typing import List, Tuple, Dict

class Rewriter:
    MODEL = "gpt-5.1"
    # Pricing for GPT-5.1 (Placeholder/Estimated)
    # Let's assume input/output are slightly higher or similar. 
    # Using $0.01/1k blended for safe estimation.
    PRICE_PER_1K_TOKENS = 0.010 

    SYSTEM_PROMPT = """You are rewriting internal residence life operations documentation.
You must preserve all facts, steps, conditions, and specific details from the input texts.
You may rephrase, reorder, merge overlapping statements, and improve clarity.
You must NOT:
- Omit any distinct piece of information.
- Change numbers, thresholds, times, or names.
- Invent new policies or procedures.
Output must be a single coherent text block suitable as a handbook / knowledge base entry."""

    def __init__(self):
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("OPENAI_API_KEY is not set.")
        self.client = openai.OpenAI(api_key=api_key)

    def estimate_cost(self, total_chars: int) -> Tuple[int, float]:
        tokens = total_chars // 4
        cost = (tokens / 1000) * self.PRICE_PER_1K_TOKENS
        return tokens, cost

    from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

    # Reuse client
    @retry(
        retry=retry_if_exception_type((openai.RateLimitError, openai.APIConnectionError, openai.APITimeoutError)),
        wait=wait_exponential(multiplier=1, min=2, max=60),
        stop=stop_after_attempt(10)
    )
    def rewrite_group(self, texts: List[str]) -> Tuple[str, Dict]:
        """
        Rewrites a list of texts into one.
        Returns (improved_text, usage_dict).
        """
        # Build prompt
        user_content = "Please rewrite the following texts into one coherent entry:\n\n"
        for i, text in enumerate(texts):
            user_content += f"Text {i+1}:\n{text}\n\n"

        # Check safety check (approx 4 chars per token)
        # GPT-4o has 128k context. Safe limit ~100k tokens -> ~400k chars.
        if len(user_content) > 400000:
            return "[ERROR: Input too long for single pass]", {"total_tokens": 0}

        # No catch block here; let tenacity handle transient errors or manager handle others
        response = self.client.chat.completions.create(
            model=self.MODEL,
            messages=[
                {"role": "system", "content": self.SYSTEM_PROMPT},
                {"role": "user", "content": user_content}
            ],
            temperature=0.3
        )
        
        content = response.choices[0].message.content
        usage = {
            "prompt_tokens": response.usage.prompt_tokens,
            "completion_tokens": response.usage.completion_tokens,
            "total_tokens": response.usage.total_tokens
        }
        return content, usage
from typing import Dict
