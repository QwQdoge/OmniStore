import os
import re

def fix_arb_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Check if there is anything after the last closing brace
    # ARB files are JSON, so they should end with }
    # Sometimes they might have another { ... } appended

    # Find all top-level blocks
    # This is a naive way to find the last valid JSON object

    # Find the last '}'
    last_brace_index = content.rfind('}')
    if last_brace_index == -1:
        return

    # Check if there is another '{' after the last '}' or multiple '}'
    # Actually, the problem mentioned is "duplicate top-level blocks from the end"

    # If we have something like { ... } { ... }
    # We want to keep only the first one if the second one is a duplicate or partial.
    # Actually, usually it means the file was appended with a full copy.

    # Let's count '{' and '}' to find the first complete object
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
    l10n_dir = 'FlutterUI/lib/l10n'
    for filename in os.listdir(l10n_dir):
        if filename.endswith('.arb'):
            fix_arb_file(os.path.join(l10n_dir, filename))

if __name__ == '__main__':
    main()
