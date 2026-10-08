"""Day 4 搜索练习 B：批量替换（练 :s、:%s//gc、smartcase）"""

RESULT_LIMIT = 10
result_count = 0


def collect(values):
    global result_count
    result_count = len(values)
    return values[:RESULT_LIMIT]


def dedup(values):
    seen = set()
    result = []
    for v in values:
        if v not in seen:
            result.append(v)
            seen.add(v)
    return result


# TODO: 给 collect 加类型注解
# TODO: 给 dedup 写测试
# todo 小写形式也会被搜到（smartcase 忽略大小写）
