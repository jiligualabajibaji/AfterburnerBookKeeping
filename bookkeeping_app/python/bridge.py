import json
from parser.engine import Engine
from parser.ai_client import AiClient

_engine: Engine | None = None

def parse_text(text: str, api_key: str = "", endpoint: str = "") -> str:
    global _engine
    if _engine is None:
        _engine = Engine(ai_client=AiClient(api_key=api_key, endpoint=endpoint))
    return json.dumps(_engine.parse(text).to_dict(), ensure_ascii=False)
