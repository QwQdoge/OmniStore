import os

print("All horizontal scrolling widgets must be wrapped in Scrollbar...")

for root, _, files in os.walk("FlutterUI/lib"):
    for file in files:
        if file.endswith(".dart"):
            with open(os.path.join(root, file)) as f:
                content = f.read()
                if "scrollDirection: Axis.horizontal" in content:
                    if "Scrollbar" not in content:
                        print(f"Missing Scrollbar in {os.path.join(root, file)}")
                    else:
                        print(f"Found horizontal scroll in {os.path.join(root, file)}")
