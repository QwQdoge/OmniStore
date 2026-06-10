import os

def fix_file(filepath):
    with open(filepath, 'r') as f:
        lines = f.readlines()

    new_lines = []
    skip = False
    in_merge = False

    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith('<<<<<<< HEAD'):
            in_merge = True
            i += 1
            continue
        elif line.startswith('======='):
            # Prefer the non-HEAD version (the one after =======)
            skip = False
            i += 1
            continue
        elif line.startswith('>>>>>>>'):
            in_merge = False
            i += 1
            continue

        if in_merge:
            # We are in the HEAD part, skip it
            i += 1
            continue

        new_lines.append(lines[i])
        i += 1

    with open(filepath, 'w') as f:
        f.writelines(new_lines)

fix_file('FlutterUI/lib/features/explore/presentation/pages/details_page.dart')
fix_file('FlutterUI/lib/services/backend_service.dart')
