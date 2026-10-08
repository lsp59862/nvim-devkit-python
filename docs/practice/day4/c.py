"""Day 4 搜索练习 C：诊断与跳转（练 <leader>sd、<leader>/）"""


def compute_loss(pred, target):
    # 故意未定义的变量：打开本文件按 <leader>sd 找到它
    return pred - target + undefined_gap


def evaluate(loader, model):
    loss_total = 0
    for batch in loader:
        loss_total += compute_loss(batch.pred, batch.target)
    return loss_total / len(loader)
