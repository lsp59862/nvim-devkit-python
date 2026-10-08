"""Day 4 搜索练习 A：函数定义与调用点（练 /、*、n/N、全项目搜索）"""


def format_metric(value, unit="ms"):
    return f"{value:.2f}{unit}"


def summarize(rows):
    total = 0.0
    for row in rows:
        total += format_metric(row)  # 调用点 1
    return format_metric(total)      # 调用点 2


def report(rows):
    lines = []
    lines.append(format_metric(len(rows)))  # 调用点 3
    lines.append(format_metric(sum(rows)))  # 调用点 4
    return lines


# 练习 5/6 用：这一行有三个 "metric"
metric_name = "metric"  # metric 出现第 1 次

metric_log = ["metric"]  # metric 出现第 2 次
