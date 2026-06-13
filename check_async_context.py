import os
import re

def check_files():
    for root, _, files in os.walk('FlutterUI/lib'):
        for file in files:
            if not file.endswith('.dart'): continue
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()

            lines = content.split('\n')
            for i, line in enumerate(lines):
                if 'await ' in line:
                    # Look ahead 15 lines
                    block_lines = lines[i+1:i+16]
                    block = '\n'.join(block_lines)

                    # Stop if we hit another method or class
                    # But just checking if 'context.' or 'ScaffoldMessenger.of(context)' or 'Navigator.of(context)'
                    # or 'showDialog(' is in the block, and 'mounted' is not.
                    if 'mounted' not in block:
                        if re.search(r'context\.(read|watch|pop|push)|ScaffoldMessenger\.of\(context\)|Navigator\.(of\(context\)|push|pop)', block):
                            print(f"[{path}:{i+1}] Missing mounted check after await:")
                            print(f"  {line.strip()}")
                            for j, bl in enumerate(block_lines[:5]):
                                print(f"  {bl.strip()}")
                            print("-" * 40)

check_files()
