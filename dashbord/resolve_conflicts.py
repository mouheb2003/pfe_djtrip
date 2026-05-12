#!/usr/bin/env python3
import re
import sys
from pathlib import Path

def resolve_conflicts_keep_head(file_path):
    """Resolve merge conflicts by keeping HEAD version"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Pattern to match: <<<<<<< HEAD ... ======= ... >>>>>>> backend/djtripx2
    pattern = r'<<<<<<< HEAD\n(.*?)\n=======\n.*?\n>>>>>>> backend/djtripx2'
    resolved = re.sub(pattern, r'\1', content, flags=re.DOTALL)

    conflicts_count = len(re.findall(pattern, content, re.DOTALL))

    if conflicts_count > 0:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(resolved)
        return conflicts_count
    return 0

# Files to process
files = [
    'd:/djtrip/dashbord/src/sections/Page1/Components/LieuDetails.jsx',
    'd:/djtrip/dashbord/src/sections/Page1.jsx',
]

for file_path in files:
    if Path(file_path).exists():
        count = resolve_conflicts_keep_head(file_path)
        if count > 0:
            print(f"✓ {file_path}: Resolved {count} conflicts")
        else:
            print(f"  {file_path}: No conflicts found")
    else:
        print(f"✗ {file_path}: File not found")

print("\nAll conflicts resolved! ✓")
