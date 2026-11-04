#!/usr/bin/env python3
"""Set the Runner's shared plist, portrait settings and minimum iOS version."""
from pathlib import Path
import plistlib
import re
import sys

def configure(root: Path) -> None:
    runner = root / 'ios/Runner'
    project = root / 'ios/Runner.xcodeproj/project.pbxproj'
    info_path = runner / 'Info.plist'
    if not project.is_file() or not info_path.is_file():
        raise RuntimeError('Restore the included DocDiary iOS Runner first.')
    with info_path.open('rb') as stream:
        base = plistlib.load(stream)
    base['CFBundleDisplayName'] = 'DocDiary'
    base.setdefault('NSCameraUsageDescription', 'DocDiary uses your camera when you choose to take a profile picture.')
    base.setdefault('NSPhotoLibraryUsageDescription', 'DocDiary lets you choose a profile picture from your photo library.')
    base['LSApplicationQueriesSchemes'] = sorted(set(base.get('LSApplicationQueriesSchemes', []) + ['mailto']))
    base['UISupportedInterfaceOrientations'] = ['UIInterfaceOrientationPortrait']
    base['UISupportedInterfaceOrientations~ipad'] = ['UIInterfaceOrientationPortrait']
    base['UIRequiresFullScreen'] = True
    base['NSAppTransportSecurity'] = {'NSAllowsArbitraryLoads': False}

    text = project.read_text()
    pattern = re.compile(r'(?m)^\t\t[A-F0-9]+ /\* (Debug|Profile|Release) \*/ = \{\n.*?^\t\t\};', re.S)
    changed = set()

    def patch_block(match):
        config = match.group(1)
        block = match.group(0)
        if not re.search(r'INFOPLIST_FILE\s*=', block):
            return block
        # Avoid the separate RunnerTests target.
        if 'Runner/Info' not in block:
            return block
        block = re.sub(r'INFOPLIST_FILE\s*=\s*[^;]+;', 'INFOPLIST_FILE = "Runner/Info.plist";', block)
        if 'CODE_SIGN_ENTITLEMENTS' not in block:
            block = block.replace('buildSettings = {', 'buildSettings = {\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;', 1)
        changed.add(config)
        return block

    text = pattern.sub(patch_block, text)
    if changed != {'Debug', 'Profile', 'Release'}:
        raise RuntimeError('The Flutter Xcode template changed. No project settings were written; review configure_ios.py.')
    text = re.sub(r'IPHONEOS_DEPLOYMENT_TARGET\s*=\s*([\d.]+);',
                  lambda m: f'IPHONEOS_DEPLOYMENT_TARGET = {max(float(m[1]), 15.0):.1f};', text)
    with info_path.open('wb') as stream:
        plistlib.dump(base, stream, sort_keys=False)

    entitlements = runner / 'Runner.entitlements'
    if not entitlements.exists():
        with entitlements.open('wb') as stream:
            plistlib.dump({'keychain-access-groups': []}, stream)

    project.write_text(text)

    podfile = root / 'ios/Podfile'
    if podfile.is_file():
        pod_text = podfile.read_text()
        if re.search(r'(?m)^#?\s*platform :ios,', pod_text):
            pod_text = re.sub(r"(?m)^#?\s*platform :ios,.*$", "platform :ios, '15.0'", pod_text)
        else:
            pod_text = "platform :ios, '15.0'\n" + pod_text
        podfile.write_text(pod_text)

    print('Configured DocDiary iOS 15+, portrait and one Info.plist.')


if __name__ == '__main__':
    configure(Path(sys.argv[1]).resolve())

