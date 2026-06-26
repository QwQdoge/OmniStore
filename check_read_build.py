import os
import re

def find_context_read_in_build():
    root_dir = 'FlutterUI/lib'
    pattern = re.compile(r'Widget\s+build\(BuildContext\s+context\s*\)\s*\{', re.MULTILINE)
    read_pattern = re.compile(r'context\.read<[^>]+>\(\)')

    for root, dirs, files in os.walk(root_dir):
        for file in files:
            if file.endswith('.dart'):
                path = os.path.join(root, file)
                with open(path, 'r') as f:
                    content = f.read()

                build_matches = list(pattern.finditer(content))
                if not build_matches:
                    continue

                for match in build_matches:
                    # Find the end of the build method (simplified: until the next method or end of class)
                    # This is hard in regex, but we can look for context.read within some lines after 'build'
                    start = match.end()
                    # Look for the next 'Widget build' or '}' at col 0 or something
                    # Let's just take a chunk of 2000 chars
                    chunk = content[start:start+2000]

                    # We want to find context.read that is NOT inside an anonymous function
                    # Anonymous functions usually have => or {

                    for read_match in read_pattern.finditer(chunk):
                        # check if it is inside a callback
                        # look backwards for => or (
                        before = chunk[:read_match.start()]
                        lines = before.splitlines()
                        if not lines:
                            print(f"Found in {path}")
                            continue

                        last_line = lines[-1]
                        if '=>' in last_line or 'onPressed' in last_line or 'onTap' in last_line or 'builder:' in last_line:
                             continue

                        # More thorough check: is there an open brace for a callback?
                        # This is still heuristic but better than nothing

                        print(f"Potential violation in {path}: {read_match.group()} at {path}")

find_context_read_in_build()
