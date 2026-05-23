import json
from typing import Optional
import httpx

CATEGORIES = ["餐饮", "交通", "购物", "娱乐", "住房", "医疗",
              "其他支出", "工资收入", "其他收入"]

class AiClient:
    def __init__(self, api_key: str = "", endpoint: str = ""):
        self.api_key = api_key
        self.endpoint = endpoint or "https://api.openai.com/v1/chat/completions"

    def parse(self, text: str) -> Optional[dict]:
        if not self.api_key:
            return None
        prompt = f"""从以下记账描述中提取信息，返回纯JSON（不要其他文字）：
原文：{text}
要求：
- amount: 数字，支出为负数，收入为正数
- category: 从 [{', '.join(CATEGORIES)}] 选最匹配的
- note: 简短备注（2-6字）
- timestamp: 如果有具体时间就返回 YYYY-MM-DD HH:mm，否则返回 YYYY-MM-DD"""
        try:
            resp = httpx.post(
                self.endpoint,
                headers={"Authorization": f"Bearer {self.api_key}",
                         "Content-Type": "application/json"},
                json={"model": "gpt-4o-mini", "messages": [{"role": "user", "content": prompt}],
                      "temperature": 0.1},
                timeout=10.0,
            )
            resp.raise_for_status()
            content = resp.json()["choices"][0]["message"]["content"]
            return json.loads(content)
        except Exception:
            return None
