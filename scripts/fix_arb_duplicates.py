import os
import re

def fix_arb_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    last_brace_index = content.rfind('}')
    if last_brace_index == -1:
        return

    count = 0
    first_end = -1
    for i, char in enumerate(content):
        if char == '{':
            count += 1
        elif char == '}':
            count -= 1
            if count == 0:
                first_end = i
                break

    if first_end != -1 and first_end < len(content) - 1:
        remaining = content[first_end+1:].strip()
        if remaining:
            print(f"Fixing {filepath}: Removing trailing content")
            new_content = content[:first_end+1]
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
                f.write('\n')

def main():
    l10n_dir = 'legacy/flutter-ui/lib/l10n'
    for filename in os.listdir(l10n_dir):
        if filename.endswith('.arb'):
            fix_arb_file(os.path.join(l10n_dir, filename))

if __name__ == '__main__':
    main()
