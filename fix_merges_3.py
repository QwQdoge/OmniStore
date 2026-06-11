import os

def fix_file(filepath):
    with open(filepath, "r") as f:
        lines = f.readlines()

    new_lines = []
    in_conflict = False
    in_head = False

    for line in lines:
        if line.startswith("<<<<<<<"):
            in_conflict = True
            in_head = True
            continue
        elif line.startswith("======="):
            in_head = False
            continue
        elif line.startswith(">>>>>>>"):
            in_conflict = False
            continue

        if in_conflict:
            if not in_head:
                new_lines.append(line)
        else:
            new_lines.append(line)

    with open(filepath, "w") as f:
        f.writelines(new_lines)

fix_file("FlutterUI/lib/features/explore/presentation/pages/details_page.dart")
fix_file("FlutterUI/lib/services/backend_service.dart")
