import re
from typing import Optional
from parser.rules import extract_amount, classify_category, detect_income
from parser.ai_client import AiClient

class ParseResult:
    def __init__(self, amount: Optional[float] = None,
                 category: Optional[str] = None,
                 note: str = "", timestamp: str = "",
                 source: str = "rule",
                 missing_fields: Optional[list[str]] = None):
        self.amount = amount
        self.category = category
        self.note = note
        self.timestamp = timestamp
        self.source = source
        self.missing_fields = missing_fields or []

    def is_complete(self) -> bool:
        return self.amount is not None and self.category is not None

    def to_dict(self) -> dict:
        return {"amount": self.amount, "category": self.category,
                "note": self.note, "timestamp": self.timestamp,
                "source": self.source, "missing_fields": self.missing_fields}

class Engine:
    def __init__(self, ai_client: Optional[AiClient] = None):
        self.ai_client = ai_client

    def parse(self, text: str) -> ParseResult:
        amount = extract_amount(text)
        category, _ = classify_category(text)
        note = self._extract_note(text)

        result = ParseResult(amount=amount, category=category, note=note, source="rule")

        use_ai = amount is None or category is None
        if use_ai and self.ai_client:
            ai_data = self.ai_client.parse(text)
            if ai_data:
                result = ParseResult(
                    amount=ai_data.get("amount", amount),
                    category=ai_data.get("category", category),
                    note=ai_data.get("note", note),
                    timestamp=ai_data.get("timestamp", ""),
                    source="ai",
                )

        missing = []
        if result.amount is None:
            missing.append("amount")
        if result.category is None:
            missing.append("category")
        result.missing_fields = missing
        return result

    def _extract_note(self, text: str) -> str:
        cleaned = text
        for pat in [r"花了?\d+\.?\d*\s*(块|元)?", r"\d+\.?\d*\s*块钱?",
                     r"付了?\d+\.?\d*", r"收入?了?\d+\.?\d*",
                     r"赚了?\d+\.?\d*", r"发了?\d+\.?\d*",
                     r"\d+\.?\d*\s*工资"]:
            cleaned = re.sub(pat, "", cleaned)
        return cleaned.strip().rstrip("，。！？,!?")[:20]
