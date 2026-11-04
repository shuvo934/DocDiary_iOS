#!/usr/bin/env python3
"""Exercise setup against an isolated Xcode configuration fixture; no SDK needed."""
import importlib.util
import json
from pathlib import Path
import plistlib
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('configure_ios', Path(__file__).with_name('configure_ios.py'))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class IosConfigurationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'ios/Runner.xcodeproj').mkdir(parents=True)
        runner = self.root / 'ios/Runner'
        runner.mkdir()
        with (runner / 'Info.plist').open('wb') as stream:
            plistlib.dump({'CFBundleName': 'docdiary_ios', 'CFBundleExecutable': '$(EXECUTABLE_NAME)',
                'UIApplicationSceneManifest': {'UIApplicationSupportsMultipleScenes': False}}, stream)
        blocks = []
        for number, name in enumerate(['Debug', 'Profile', 'Release'], 1):
            blocks.append('\t\t' + f'{number:024X} /* {name} */ = {{\n'
              '\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n'
              '\t\t\t\tINFOPLIST_FILE = Runner/Info.plist;\n'
              '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.app;\n'
              '\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 13.0;\n'
              '\t\t\t};\n\t\t\tname = ' + name + ';\n\t\t};')
        self.project = self.root / 'ios/Runner.xcodeproj/project.pbxproj'
        self.project.write_text('\n'.join(blocks))
        (self.root / 'ios/Podfile').write_text("# platform :ios, '13.0'\n")

    def read_info(self):
        with (self.root / 'ios/Runner/Info.plist').open('rb') as stream:
            return plistlib.load(stream)

    def test_one_plist_requests_portrait_and_uses_default_ats(self):
        MODULE.configure(self.root)
        info = self.read_info()
        self.assertFalse(info['NSAppTransportSecurity']['NSAllowsArbitraryLoads'])
        self.assertTrue(info['UIRequiresFullScreen'])
        for key in ['UISupportedInterfaceOrientations', 'UISupportedInterfaceOrientations~ipad']:
            self.assertEqual(info[key], ['UIInterfaceOrientationPortrait'])
        self.assertEqual(list((self.root / 'ios/Runner').glob('Info*.plist')),
                         [self.root / 'ios/Runner/Info.plist'])

    def test_generated_flutter_scene_settings_are_preserved(self):
        MODULE.configure(self.root)
        self.assertIn('UIApplicationSceneManifest', self.read_info())

    def test_each_build_configuration_references_correct_info_and_keychain(self):
        MODULE.configure(self.root)
        text = self.project.read_text()
        self.assertEqual(text.count('Runner/Info.plist'), 3)
        self.assertEqual(text.count('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'), 3)

    def test_configuration_can_be_rerun_without_duplicate_settings(self):
        MODULE.configure(self.root)
        first = self.project.read_text()
        MODULE.configure(self.root)
        self.assertEqual(self.project.read_text(), first)

    def test_ios_minimum_is_set_and_bundle_id_preserved(self):
        MODULE.configure(self.root)
        text = self.project.read_text()
        self.assertEqual(text.count('IPHONEOS_DEPLOYMENT_TARGET = 15.0;'), 3)
        self.assertEqual(text.count('com.example.app'), 3)
        self.assertIn("platform :ios, '15.0'", (self.root / 'ios/Podfile').read_text())

    def test_unrecognized_xcode_template_fails_without_writing_project(self):
        self.project.write_text('unrecognized template')
        with self.assertRaises(RuntimeError): MODULE.configure(self.root)
        self.assertEqual(self.project.read_text(), 'unrecognized template')


if __name__ == '__main__':
    unittest.main()
