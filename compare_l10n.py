import json
import os

def load_arb(path):
    with open(path, 'r') as f:
        return json.load(f)

en = load_arb('FlutterUI/lib/l10n/app_en.arb')
zh = load_arb('FlutterUI/lib/l10n/app_zh.arb')
zh_hant = load_arb('FlutterUI/lib/l10n/app_zh_Hant.arb')

en_keys = set(en.keys())
zh_keys = set(zh.keys())
zh_hant_keys = set(zh_hant.keys())

print(f"Missing in zh: {en_keys - zh_keys}")
print(f"Missing in zh_Hant: {en_keys - zh_hant_keys}")

# Check order
en_key_list = [k for k in en.keys() if not k.startswith('@')]
zh_key_list = [k for k in zh.keys() if not k.startswith('@')]
zh_hant_key_list = [k for k in zh_hant.keys() if not k.startswith('@')]

def check_order(base, target, name):
    common = [k for k in base if k in target]
    target_common = [k for k in target if k in base]
    if common != target_common:
        print(f"Order mismatch in {name}")
        # Find first mismatch
        for i in range(min(len(common), len(target_common))):
            if common[i] != target_common[i]:
                print(f"First mismatch at index {i}: expected {common[i]}, got {target_common[i]}")
                break

check_order(en_key_list, zh_key_list, "zh")
check_order(en_key_list, zh_hant_key_list, "zh_Hant")
