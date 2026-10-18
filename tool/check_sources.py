#!/usr/bin/env python3
"""Offline file/asset/import/delimiter checks. This is NOT a Dart compiler."""
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


class DelimiterCheck:
    def __init__(self, text):
        self.text, self.i, self.stack = text, 0, []

    def fail(self, message):
        line = self.text.count('\n', 0, self.i) + 1
        raise ValueError(f'line {line}: {message}')

    def string(self, raw=False):
        quote = self.text[self.i]
        marker = quote * (3 if self.text.startswith(quote * 3, self.i) else 1)
        self.i += len(marker)
        while self.i < len(self.text):
            if self.text.startswith(marker, self.i):
                self.i += len(marker)
                return
            if not raw and self.text[self.i] == '\\':
                self.i += 2
            elif not raw and self.text.startswith('${', self.i):
                self.i += 2
                self.code(interpolation=True)
            else:
                self.i += 1
        self.fail('unterminated string')

    def code(self, interpolation=False):
        initial_depth = len(self.stack)
        while self.i < len(self.text):
            if self.text.startswith('//', self.i):
                end = self.text.find('\n', self.i)
                self.i = len(self.text) if end < 0 else end + 1
                continue
            if self.text.startswith('/*', self.i):
                self.i += 2
                depth = 1
                while self.i < len(self.text) and depth:
                    if self.text.startswith('/*', self.i):
                        depth += 1; self.i += 2
                    elif self.text.startswith('*/', self.i):
                        depth -= 1; self.i += 2
                    else:
                        self.i += 1
                if depth: self.fail('unterminated comment')
                continue
            ch = self.text[self.i]
            if ch == 'r' and self.i + 1 < len(self.text) and self.text[self.i + 1] in "\"'":
                self.i += 1
                self.string(raw=True)
                continue
            if ch in "\"'":
                self.string()
                continue
            if ch in '([{': self.stack.append(ch)
            if ch in ')]}':
                if interpolation and ch == '}' and len(self.stack) == initial_depth:
                    self.i += 1
                    return
                if not self.stack or self.stack.pop() != {')': '(', ']': '[', '}': '{'}[ch]:
                    self.fail('mismatched closing delimiter ' + ch)
            self.i += 1
        if interpolation: self.fail('unterminated interpolation')
        if self.stack: self.fail('unclosed delimiters ' + ''.join(self.stack))


def check():
    failures = []
    paths = sorted((ROOT / 'lib').rglob('*.dart')) + sorted((ROOT / 'test').rglob('*.dart'))
    for path in paths:
        text = path.read_text()
        try:
            DelimiterCheck(text).code()
        except ValueError as error:
            failures.append(f'{path.relative_to(ROOT)}: {error}')
        for target in re.findall(r"(?:import|export)\s+'([^']+)'", text):
            if target.startswith('package:docdiary_ios/'):
                resolved = ROOT / 'lib' / target.split('/', 1)[1]
            elif ':' not in target:
                resolved = path.parent / target
            else:
                continue
            if not resolved.is_file(): failures.append(f'Missing import {target} in {path.name}')
        for asset in re.findall(r"['\"](assets/images/[^'\"]+)['\"]", text):
            if not (ROOT / asset).is_file(): failures.append('Missing asset: ' + asset)
    for relative in ['lib/main.dart', 'pubspec.yaml', 'tool/bootstrap_ios.sh', 'docs/native_baseline.json']:
        if not (ROOT / relative).is_file(): failures.append('Missing required file: ' + relative)
    result = {'check': 'offline source consistency (not Flutter/Dart analysis)',
              'dart_files_inspected': len(paths), 'failures': failures}
    print(json.dumps(result, indent=2))
    return not failures


if __name__ == '__main__':
    sys.exit(0 if check() else 1)

