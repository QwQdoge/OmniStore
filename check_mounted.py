import os
import re

def check_files():
    for root, _, files in os.walk('FlutterUI/lib'):
        for file in files:
            if not file.endswith('.dart'): continue
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()

            # Simple heuristic: find 'await ', then look for 'context' or 'widget' or 'Navigator' or 'ScaffoldMessenger' or 'showDialog' in the same block, without 'mounted'
            # Let's just print functions containing 'await' and not 'mounted'

            lines = content.split('\n')
            for i, line in enumerate(lines):
                if 'await ' in line:
                    # check next 10 lines
                    next_lines = lines[i+1:i+11]
                    block = '\n'.join(next_lines)
                    if 'mounted' not in block and any(x in block for x in ['context', 'widget.', 'Navigator.', 'ScaffoldMessenger.']):
                        print(f"Possible missing mounted check in {path} around line {i+1}")
                        for j in range(max(0, i-2), min(len(lines), i+8)):
                            print(f"{j+1}: {lines[j]}")
                        print("-" * 40)

check_files()
