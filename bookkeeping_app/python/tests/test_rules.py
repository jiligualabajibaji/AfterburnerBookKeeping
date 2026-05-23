import pytest
from parser.rules import extract_amount, classify_category, detect_income

class TestExtractAmount:
    def test_standard_块(self):
        assert extract_amount("花了38块") == 38.0
    def test_standard_元(self):
        assert extract_amount("付了15元") == 15.0
    def test_decimal(self):
        assert extract_amount("花了15.5元") == 15.5
    def test_income(self):
        assert extract_amount("发了5000工资") == 5000.0
    def test_no_amount(self):
        assert extract_amount("今天去吃饭了") is None
    def test_empty(self):
        assert extract_amount("") is None

class TestClassifyCategory:
    def test_food(self):
        cat, _ = classify_category("中午吃饭花了38")
        assert cat == "餐饮"
    def test_transport(self):
        cat, _ = classify_category("打车去公司15块")
        assert cat == "交通"
    def test_no_match(self):
        cat, _ = classify_category("今天天气不错")
        assert cat is None
    def test_multi_match(self):
        cat, _ = classify_category("买电影票花了80")
        assert cat is None  # "买"→购物, "电影"→娱乐

class TestDetectIncome:
    def test_salary(self):
        assert detect_income("发了8000工资") is True
    def test_expense(self):
        assert detect_income("吃饭花了38") is False
