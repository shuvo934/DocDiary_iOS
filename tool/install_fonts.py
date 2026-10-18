#!/usr/bin/env python3
"""Install upstream native font families, preserving other pubspec settings."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
BASE = 'https://raw.githubusercontent.com/google/fonts/main/'
FAMILIES = {
    'Poppins': ('ofl/poppins/', 'OFL.txt', [
        ('Poppins-Regular.ttf', 400), ('Poppins-Medium.ttf', 500),
        ('Poppins-SemiBold.ttf', 600), ('Poppins-Bold.ttf', 700)]),
    'PatuaOne': ('ofl/patuaone/', 'OFL.txt', [('PatuaOne-Regular.ttf', 400)]),
    'Ubuntu': ('ufl/ubuntu/', 'UFL.txt', [('Ubuntu-Medium.ttf', 500)]),
    'OpenSans': ('ofl/opensans/', 'OFL.txt', [('OpenSans[wdth,wght].ttf', 400)]),
    'Archivo': ('ofl/archivo/', 'OFL.txt', [('Archivo[wdth,wght].ttf', 700)]),
    'Baloo': ('', 'OFL.txt', [('Baloo-Regular.ttf', 400)]),
    'Roboto': ('', 'LICENSE.txt', [('Roboto-Regular.ttf', 400), ('Roboto-Bold.ttf', 700)]),
}

# Original Baloo (not Baloo 2) is retained by Google's font-serving endpoint.
DIRECT_SOURCES = {
    'Baloo-Regular.ttf': 'https://fonts.gstatic.com/s/baloo/v14/6xKhdSpJJ92I9MWPCms.ttf',
    'Baloo-OFL.txt': 'https://raw.githubusercontent.com/EkType/Baloo/master/OFL.txt',
    'Roboto-Regular.ttf': 'https://android.googlesource.com/platform/external/roboto-fonts/+/android11-release/Roboto-Regular.ttf?format=TEXT',
    'Roboto-Bold.ttf': 'https://android.googlesource.com/platform/external/roboto-fonts/+/android11-release/Roboto-Bold.ttf?format=TEXT',
    'Roboto-LICENSE.txt': 'https://android.googlesource.com/platform/external/roboto-fonts/+/android11-release/NOTICE?format=TEXT',
}


def fetch(url, path, font=False):
    if path.exists():
        data = path.read_bytes()
    else:
        last_error = None
        for _ in range(2):
            try:
                with urllib.request.urlopen(url, timeout=15) as response:
                    data = response.read(8 * 1024 * 1024)
                if url.endswith('?format=TEXT'):
                    data = base64.b64decode(data)
                break
            except OSError as error:
                last_error = error
        else:
            raise last_error
    if not data or (font and data[:4] not in [b'\x00\x01\x00\x00', b'OTTO', b'ttcf']):
        raise ValueError('Expected font data is missing or invalid: ' + path.name)
    if not path.exists():
        path.write_bytes(data)
    return hashlib.sha256(data).hexdigest()


def merge_font_declarations(text, families):
    """Replace only managed font families inside flutter/fonts, keeping peers."""
    lines = text.splitlines()
    flutter = next((i for i, line in enumerate(lines) if line == 'flutter:'), None)
    if flutter is None:
        raise ValueError('pubspec.yaml has no flutter section.')
    end = next((i for i in range(flutter + 1, len(lines))
                if lines[i] and not lines[i][0].isspace()
                and not lines[i].startswith('#')), len(lines))
    start = next((i for i in range(flutter + 1, end)
                  if re.fullmatch(r'  fonts:\s*(?:#.*)?', lines[i])), None)
    if start is None:
        start = end
        stop = end
        retained = []
    else:
        stop = next((i for i in range(start + 1, end)
                     if lines[i].strip() and not lines[i].lstrip().startswith('#')
                     and len(lines[i]) - len(lines[i].lstrip()) <= 2), end)
        retained = []
        dropping = False
        for line in lines[start + 1:stop]:
            match = re.match(r'    - family:\s*[\'\"]?([^\'\"#]+?)[\'\"]?\s*(?:#.*)?$', line)
            if match:
                dropping = match.group(1).strip() in families
            if not dropping:
                retained.append(line)
    declaration = ['  fonts:'] + retained
    for family, fonts in families.items():
        declaration += ['    - family: ' + family, '      fonts:']
        for filename, weight in fonts:
            declaration += ['        - asset: assets/fonts/' + filename,
                            '          weight: ' + str(weight)]
    return '\n'.join(lines[:start] + declaration + lines[stop:]) + '\n'


def install(strict=False):
    output = ROOT / 'assets/fonts'
    output.mkdir(parents=True, exist_ok=True)
    ready, manifest, failures = {}, [], []
    for family, (directory, licence, fonts) in FAMILIES.items():
        try:
            licence_file = family + '-' + licence
            fetch(DIRECT_SOURCES.get(licence_file, BASE + directory + licence),
                  output / licence_file)
            records = []
            for filename, weight in fonts:
                url = DIRECT_SOURCES.get(filename,
                    BASE + directory + urllib.parse.quote(filename))
                digest = fetch(url, output / filename, font=True)
                records.append({'file': filename, 'source': url, 'sha256': digest})
            ready[family] = fonts
            manifest += records
        except (OSError, ValueError) as error:
            failures.append(family)
            print('Font unavailable for ' + family + ': ' + str(error))
    if strict and failures:
        raise RuntimeError('Native font setup incomplete: ' + ', '.join(failures)
                           + '. pubspec.yaml was not changed. Retry when connected.')
    if ready:
        pubspec = ROOT / 'pubspec.yaml'
        pubspec.write_text(merge_font_declarations(pubspec.read_text(), ready))
        (output / 'font_sources.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Native fonts ready: ' + ', '.join(ready))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--strict', action='store_true')
    install(strict=parser.parse_args().strict)

