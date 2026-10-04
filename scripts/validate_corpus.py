#!/usr/bin/env python3
"""Optional external corpus check. Requires psd-tools and numpy in a test environment."""
# Copyright (c) 2026 Moosh Massacre. SPDX-License-Identifier: MIT
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib
import numpy as np
from psd_tools import PSDImage
from psd_tools.api.utils import has_transparency
from psd_tools.constants import Resource

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tests'))
from test_conversion import png

parser = argparse.ArgumentParser()
parser.add_argument('corpus', type=Path)
parser.add_argument('--report', type=Path, default=Path('corpus-report.json'))
args = parser.parse_args()
records = []
with tempfile.TemporaryDirectory() as temporary:
    for original in sorted(args.corpus.rglob('*')):
        if original.suffix.lower() not in ['.psd', '.psb']:
            continue
        data = original.read_bytes()
        if len(data) < 26:
            continue
        depth, mode = struct.unpack('>HH', data[22:26])
        if depth not in [8, 16] or mode not in [1, 3]:
            continue
        record = {'file': str(original.relative_to(args.corpus)), 'depth': depth, 'mode': mode}
        target = Path(temporary) / original.name
        target.with_suffix('.png').unlink(missing_ok=True)
        shutil.copy2(original, target)
        result = subprocess.run([str(ROOT/'dist/bin/psd-to-png'), '--collision', 'replace', str(target)], capture_output=True, text=True)
        if result.returncode:
            record['status'] = 'rejected'
            record['reason'] = result.stderr.strip()
        else:
            try:
                psd = PSDImage.open(original)
                planes = psd._record.image_data.get_data(psd._record.header)
                colors = 3 if mode == 3 else 1
                array = np.stack([np.frombuffer(p, dtype='u1' if depth == 8 else '>u2').reshape(psd.height, psd.width) for p in planes], axis=-1)
                alpha = has_transparency(psd)
                expected = array[:, :, :colors+alpha].astype(np.int64)
                maximum = (1 << depth)-1
                if alpha:
                    a = expected[:, :, colors:colors+1]
                    expected[:, :, :colors] = np.where(a == 0, 0, np.clip(((expected[:, :, :colors]+a-maximum)*maximum+a//2)//np.maximum(a, 1), 0, maximum))
                chunks, actual = png(target.with_suffix('.png'))
                icc = psd.image_resources.get_data(Resource.ICC_PROFILE)
                if icc:
                    payload = chunks[b'iCCP']
                    name_end = payload.index(0)
                    assert payload[name_end+1] == 0
                    assert zlib.decompress(payload[name_end+2:]) == icc, 'ICC profile mismatch'
                    record['icc_preserved'] = True
                count = {0:1, 2:3, 4:2, 6:4}[chunks[b'IHDR'][9]]
                row = psd.width*count*(depth//8)
                raw = b''.join(actual[i+1:i+row+1] for i in range(0, len(actual), row+1))
                output = np.frombuffer(raw, dtype='u1' if depth == 8 else '>u2').reshape(psd.height, psd.width, count)
                if expected.shape != output.shape or not np.array_equal(expected, output):
                    raise AssertionError('Composite pixel mismatch')
                record['status'] = 'matched'
            except Exception as error:
                record['status'] = 'mismatch'
                record['reason'] = str(error)
        assert hashlib.sha256(original.read_bytes()).digest() == hashlib.sha256(data).digest(), 'Source changed'
        records.append(record)
summary = {status: sum(r['status'] == status for r in records) for status in ['matched', 'rejected', 'mismatch']}
args.report.write_text(json.dumps({'summary': summary, 'files': records}, indent=2))
print(json.dumps(summary))
sys.exit(1 if summary['mismatch'] else 0)
