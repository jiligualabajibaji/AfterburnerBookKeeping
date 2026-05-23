import json
import pytest
from parser.engine import Engine

class TestEngine:
    def test_simple_expense(self):
        r = Engine().parse("今天中午吃饭花了38")
        assert r.amount == 38.0 and r.category == "餐饮" and r.is_complete()

    def test_income(self):
        r = Engine().parse("发了8000工资")
        assert r.amount == 8000.0 and r.is_complete()

    def test_missing_amount(self):
        r = Engine().parse("今天去吃饭了")
        assert not r.is_complete() and "amount" in r.missing_fields

    def test_missing_category(self):
        r = Engine().parse("花了99块钱")
        assert r.amount == 99.0 and "category" in r.missing_fields

    def test_bridge_output(self):
        import bridge
        j = bridge.parse_text("打车花了15块")
        d = json.loads(j)
        assert d["amount"] == 15.0 and d["category"] == "交通"
