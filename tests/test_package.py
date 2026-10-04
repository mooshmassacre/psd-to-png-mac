"""Exercise installation, update, rollback, uninstallation and workflow wiring."""
# Copyright (c) 2026 Moosh Massacre. SPDX-License-Identifier: MIT
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]

class Packaging(unittest.TestCase):
    def test_workflow(self):
        contents=ROOT/'Resources/PSD to PNG.workflow/Contents'
        info=plistlib.loads((contents/'Info.plist').read_bytes())
        flow=plistlib.loads((contents/'document.wflow').read_bytes())
        self.assertEqual(info['NSServices'][0]['NSMenuItem']['default'],'PSD to PNG')
        params=flow['actions'][0]['action']['ActionParameters']
        self.assertEqual(params['inputMethod'],1)
        self.assertIn('PSD_to_PNG.command" "$@"',params['COMMAND_STRING'])
    def test_install_update_uninstall(self):
        with tempfile.TemporaryDirectory() as temp:
            user=Path(temp)/'test account';user.mkdir()
            env=dict(os.environ,PSD_TO_PNG_USER_ROOT=str(user),PSD_TO_PNG_QUIET='1')
            target=user/'Library/Application Support/PSD to PNG';service=user/'Library/Services/PSD to PNG.workflow'
            unrelated=user/'original.psd';unrelated.write_bytes(b'keep')
            for _ in range(2):
                subprocess.run(['/bin/bash',str(ROOT/'Install PSD to PNG.command')],env=env,check=True,capture_output=True)
                self.assertTrue((target/'bin/psd-to-png').is_file());self.assertTrue((service/'Contents/document.wflow').is_file())
            self.assertEqual(len(list(target.parent.glob('PSD to PNG.backup-*'))),1)
            self.assertEqual(len(list(service.parent.glob('*.backup-*'))),0)
            self.assertEqual(len(list((user/'Library/Application Support/PSD to PNG Backups').glob('*.workflow'))),1)
            subprocess.run(['/bin/bash',str(ROOT/'Uninstall PSD to PNG.command')],env=env,check=True,capture_output=True)
            self.assertFalse(target.exists());self.assertFalse(service.exists());self.assertEqual(unrelated.read_bytes(),b'keep')
            self.assertEqual(len(list(target.parent.glob('PSD to PNG.backup-*'))),1)
    def test_staging_failure_preserves_installation(self):
        with tempfile.TemporaryDirectory() as temp:
            folder=Path(temp);package=folder/'package';package.mkdir();user=folder/'account'
            shutil.copy2(ROOT/'Install PSD to PNG.command',package)
            (package/'dist/bin').mkdir(parents=True);shutil.copy2(ROOT/'dist/bin/psd-to-png',package/'dist/bin/psd-to-png')
            target=user/'Library/Application Support/PSD to PNG';target.mkdir(parents=True);(target/'sentinel').write_bytes(b'previous')
            result=subprocess.run(['/bin/bash',str(package/'Install PSD to PNG.command')],env=dict(os.environ,PSD_TO_PNG_USER_ROOT=str(user),PSD_TO_PNG_QUIET='1'),capture_output=True)
            self.assertEqual(result.returncode,1);self.assertEqual((target/'sentinel').read_bytes(),b'previous')
            self.assertFalse(list(target.parent.glob('.psd-to-png-install.*')))
