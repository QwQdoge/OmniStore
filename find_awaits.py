import os
import re

def check_files():
    pattern = re.compile(r'await\s+[^;]+;\s*(?:if\s*\(!?mounted\)\s*return;\s*)?([^}]+)', re.MULTILINE)

    for root, _, files in os.walk('FlutterUI/lib'):
        for file in files:
            if not file.endswith('.dart'): continue
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()

            lines = content.split('\n')

            for i, line in enumerate(lines):
                if 'await ' in line:
                    block = '\n'.join(lines[i+1:i+10])
                    if 'mounted' not in block:
                        if 'context.' in block or 'of(context)' in block:
                            print(f"[{path}:{i+1}] {line.strip()}")
                            for j in range(i+1, min(len(lines), i+6)):
                                print(f"  {lines[j].strip()}")

check_files()
