import re
from typing import Optional

AMOUNT_PATTERNS = [
    re.compile(r"花了?(\d+\.?\d*)\s*块"),
    re.compile(r"花了?(\d+\.?\d*)\s*元"),
    re.compile(r"花了?(\d+\.?\d*)"),
    re.compile(r"(\d+\.?\d*)\s*块钱"),
    re.compile(r"付了?(\d+\.?\d*)"),
    re.compile(r"收入?了?(\d+\.?\d*)"),
    re.compile(r"赚了?(\d+\.?\d*)"),
    re.compile(r"发了?(\d+\.?\d*)"),
    re.compile(r"(\d+\.?\d*)\s*工资"),
]

CATEGORY_KEYWORDS: dict[str, list[str]] = {
    "餐饮": ["早餐", "午餐", "晚餐", "早", "中", "晚", "饭", "吃", "咖啡", "奶茶",
             "外卖", "餐厅", "食堂", "面", "粉", "小吃", "夜宵", "点餐"],
    "交通": ["地铁", "公交", "打车", "滴滴", "出租车", "加油", "停车", "高铁",
             "机票", "火车", "单车", "骑车", "出行"],
    "购物": ["买", "衣服", "鞋", "淘宝", "京东", "拼多多", "超市", "便利店", "日用", "数码"],
    "娱乐": ["电影", "KTV", "游戏", "充值", "会员", "门票", "健身", "运动", "旅行"],
    "住房": ["房租", "水电", "物业", "燃气", "网费", "维修"],
    "医疗": ["医院", "药", "看病", "体检", "牙"],
    "工资收入": ["工资", "兼职", "奖金", "薪水", "月薪", "劳务", "提成"],
    "其他收入": ["红包", "退款", "利息", "理财", "中奖", "报销"],
}


def extract_amount(text: str) -> Optional[float]:
    for pat in AMOUNT_PATTERNS:
        m = pat.search(text)
        if m:
            return float(m.group(1))
    return None


def classify_category(text: str) -> tuple[Optional[str], list[str]]:
    matched: list[str] = []
    for cat, keywords in CATEGORY_KEYWORDS.items():
        for kw in keywords:
            if kw in text:
                matched.append(cat)
                break
    if len(matched) == 1:
        return matched[0], matched
    return None, matched


def detect_income(text: str) -> bool:
    income_kw = {"工资", "收入", "赚", "发", "兼职", "奖金", "红包", "退款", "报销"}
    return any(kw in text for kw in income_kw)
