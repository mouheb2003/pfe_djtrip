#!/usr/bin/env python3
import re
import sys

def resolve_conflicts(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Pattern to match conflict blocks
    # Keeps the HEAD version (first part)
    pattern = r'<<<<<<< HEAD\n(.*?)\n=======\n(?:.*?)\n>>>>>>> [^\n]+\n'
    
    resolved = re.sub(pattern, r'\1\n', content, flags=re.DOTALL)
    
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(resolved)
    
    print(f"Resolved conflicts in {filename}")

if __name__ == "__main__":
    files = [
        "lib/screens/tourist/place_detail_screen.dart",
        "lib/screens/tourist/my_activities_screen.dart"
    ]
    
    for file in files:
        try:
            resolve_conflicts(file)
        except Exception as e:
            print(f"Error processing {file}: {e}", file=sys.stderr)
