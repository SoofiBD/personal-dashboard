#!/usr/bin/env python3
"""Check Git-visible files without printing credential values. Run before push."""
import json
import re
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
paths = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=root).decode().split('\0')
known = []
recovery = root / '.private/nas-recovery.json'
if recovery.exists():
    known = [str(value).encode() for key, value in json.loads(recovery.read_text()).items()
             if key in ('NAS_PASSWORD', 'WEB_PASSWORD', 'NAS_HOST') and len(str(value)) >= 6]
findings = []
for name in sorted(set(filter(None, paths))):
    path = root / name
    if not path.is_file():
        continue
    if '.private' in path.parts or (path.name.startswith('.env.nas') and not path.name.endswith('.example')) or re.search(r'\.(pem|key)(\.bak)?$', name):
        findings.append((name, 'private file'))
        continue
    data = path.read_bytes()
    # Inspect staged content too: a clean working copy can hide a staged secret.
    staged = subprocess.run(['git', 'show', ':' + name], cwd=root, capture_output=True)
    if staged.returncode == 0:
        data += b'\n' + staged.stdout
    if any(secret in data for secret in known):
        findings.append((name, 'recovered credential'))
    if re.search(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----', data):
        findings.append((name, 'private key'))
    # Literal production NAS credentials are forbidden; ENV lookups are permitted.
    for match in re.finditer(rb'(?m)^\s*(?:NAS_PASSWORD|NAS_API_TOKEN)\s*=\s*([\'\"])([^\r\n]+?)\1\s*$', data):
        value = match.group(2)
        if not name.endswith('.example') and len(value) >= 8:
            findings.append((name, 'hardcoded NAS credential'))
for name, reason in findings:
    print(f'BLOCKED: {name}: {reason}')
print(f'NAS secret check: {len(set(paths)) - 1} Git-visible files; {len(findings)} findings. Values never printed.')
sys.exit(bool(findings))
