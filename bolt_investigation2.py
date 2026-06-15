import re
import os

for root, _, files in os.walk("FlutterUI/lib"):
    for file in files:
        if file.endswith(".dart"):
            with open(os.path.join(root, file), 'r') as f:
                content = f.read()

                # Find all CachedNetworkImage instances
                images = re.split(r'CachedNetworkImage\s*\(', content)[1:]
                for i, img in enumerate(images):
                    # extract the block up to the matching closing parenthesis
                    open_parens = 1
                    block = ""
                    for char in img:
                        block += char
                        if char == '(': open_parens += 1
                        elif char == ')': open_parens -= 1
                        if open_parens == 0:
                            break

                    if "memCacheWidth" not in block and "memCacheHeight" not in block:
                        print(f"Missing memCache in {os.path.join(root, file)} (instance {i+1})")
