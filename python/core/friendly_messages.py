import random

def get_friendly_message():
    messages = [
        "祝你有美好的一天！",
        "今天也是充满希望的一天呢。",
        "OmniStore 正在为你努力工作中...",
        "又是元气满满的一天！",
        "喝杯咖啡，休息一下吧。",
        "感谢使用 OmniStore！",
        "保持微笑，好运会降临哦。",
        "Have a wonderful day!",
        "Keep up the great work!",
        "Stay curious, stay inspired.",
        "You're doing amazing!",
        "Happiness is an inside job.",
        "Que tengas un gran día!",
        "¡Eres increíble!",
        "素晴らしい一日を！",
        "今日も一日頑張りましょう！",
        "あなたの作業が捗りますように。"
    ]
    return random.choice(messages)
