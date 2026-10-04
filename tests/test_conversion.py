"""Independent PSD/PSB fixtures and PNG pixel validation. Standard library only."""
# Copyright (c) 2026 Moosh Massacre. SPDX-License-Identifier: MIT
from concurrent.futures import ThreadPoolExecutor
import hashlib
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[1]
BIN = ROOT / 'dist/bin/psd-to-png'

def pack(n, size):
    return n.to_bytes(size, 'big')

def resource(identifier, payload):
    return b'8BIM' + pack(identifier, 2) + b'\0\0' + pack(len(payload), 4) + payload + b'\0' * (len(payload) % 2)

def document(version=1, depth=8, mode=3, compression=0, alpha=False, tagged=False, extra=False, compatible=True, width=3, height=2):
    colors = 3 if mode == 3 else 1
    channels = colors + alpha + extra
    maximum = (1 << depth) - 1
    samples = [[(i * 7919 + c * 17011) % (maximum + 1) for i in range(width * height)] for c in range(channels)]
    if alpha:
        samples[colors] = [0, maximum, maximum // 2, maximum // 3, maximum, maximum // 4][:width*height]
    planes = b''.join(pack(v, depth//8) for channel in samples for v in channel)
    rows = [planes[i:i+width*(depth//8)] for i in range(0, len(planes), width*(depth//8))]
    if compression == 0:
        payload = planes
    elif compression == 1:
        encoded = [bytes([len(row)-1]) + row for row in rows]
        payload = b''.join(pack(len(row), 4 if version == 2 else 2) for row in encoded) + b''.join(encoded)
    elif compression == 2:
        payload = zlib.compress(planes)
    else:
        encoded = bytearray()
        for row in rows:
            previous = 0
            for i in range(0, len(row), depth//8):
                value = int.from_bytes(row[i:i+depth//8], 'big')
                encoded.extend(pack((value-previous) & maximum, depth//8)); previous = value
        payload = zlib.compress(encoded)
    size = 8 if version == 2 else 4
    layers = b''
    if alpha:
        if tagged:
            key = b'Mt16' if depth == 16 else b'Mtrn'
            layers = pack(0,size) + pack(0,4) + b'8BIM' + key + pack(0,size if version == 2 else 4)
        else:
            layers = pack(2,size) + b'\xff\xff' + pack(0,4)
    resources = resource(1057, pack(1,4) + bytes([compatible]) + b'\0'*12)
    header = b'8BPS' + pack(version,2) + b'\0'*6 + pack(channels,2) + pack(height,4) + pack(width,4) + pack(depth,2) + pack(mode,2)
    expected = bytearray()
    for y in range(height):
        expected.append(0)
        for x in range(width):
            i = y*width+x
            a = samples[colors][i] if alpha else maximum
            for c in range(colors+alpha):
                value = samples[c][i]
                if alpha and c < colors:
                    value = 0 if a == 0 else max(0,min(maximum,((value+a-maximum)*maximum+a//2)//a))
                expected.extend(pack(value,depth//8))
    return header + pack(0,4) + pack(len(resources),4) + resources + pack(len(layers),size) + layers + pack(compression,2) + payload, bytes(expected)

def png(path):
    data = path.read_bytes(); assert data[:8] == b'\x89PNG\r\n\x1a\n'
    pos = 8; chunks = {}; compressed = b''
    while pos < len(data):
        n = int.from_bytes(data[pos:pos+4],'big'); name = data[pos+4:pos+8]; value = data[pos+8:pos+8+n]
        assert zlib.crc32(name+value) == int.from_bytes(data[pos+8+n:pos+12+n],'big')
        chunks[name] = value
        if name == b'IDAT': compressed += value
        pos += n+12
    return chunks, zlib.decompress(compressed)

class Conversion(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.folder = Path(self.tmp.name)
    def tearDown(self): self.tmp.cleanup()
    def run_files(self, files, choice='copy'):
        return subprocess.run([str(BIN),'--collision',choice,*map(str,files)],capture_output=True,text=True)
    def test_matrix(self):
        for version in [1,2]:
            for depth in [8,16]:
                for mode in [1,3]:
                    for compression in range(4):
                        for alpha in [False,True]:
                            for tagged in ([False,True] if alpha else [False]):
                                with self.subTest(version=version,depth=depth,mode=mode,compression=compression,alpha=alpha,tagged=tagged):
                                    data,expected = document(version,depth,mode,compression,alpha,tagged)
                                    source=self.folder/'Á test [1].{}'.format('psb' if version==2 else 'psd'); source.write_bytes(data)
                                    target=source.with_suffix('.png'); target.unlink(missing_ok=True)
                                    result=self.run_files([source]); self.assertEqual(result.returncode,0,result.stderr)
                                    chunks,actual=png(target); self.assertEqual(actual,expected)
                                    self.assertEqual(chunks[b'IHDR'][8],depth)
                                    self.assertEqual(source.read_bytes(),data)
    def test_conflicts(self):
        source=self.folder/'name.psd'; data,_=document(); source.write_bytes(data)
        target=source.with_suffix('.png'); target.write_bytes(b'old')
        self.assertEqual(self.run_files([source],'cancel').returncode,0);self.assertEqual(target.read_bytes(),b'old')
        for expected in ['name copy.png','name copy 2.png','name copy 3.png']:
            self.assertEqual(self.run_files([source]).returncode,0);self.assertTrue((self.folder/expected).exists())
        self.assertEqual(target.read_bytes(),b'old')
        self.assertEqual(self.run_files([source],'replace').returncode,0);png(target)
        self.assertEqual(source.read_bytes(),data)
    def test_extra_alpha_is_not_transparency(self):
        source=self.folder/'spot.psb'; data,expected=document(version=2,extra=True);source.write_bytes(data)
        self.assertEqual(self.run_files([source]).returncode,0)
        chunks,actual=png(source.with_suffix('.png'));self.assertEqual(chunks[b'IHDR'][9],2);self.assertEqual(actual,expected)
    def test_reject_and_continue(self):
        bad=self.folder/'bad.psd';good=self.folder/'good.PSB'
        bad.write_bytes(document(compatible=False)[0]);good.write_bytes(document(version=2)[0])
        result=self.run_files([bad,good]);self.assertEqual(result.returncode,1);self.assertFalse(bad.with_suffix('.png').exists());self.assertTrue(good.with_suffix('.png').exists())
    def test_malformed(self):
        data,_=document(compression=1)
        source=self.folder/'broken.psd'
        for payload in [b'nope',data[:20],data[:-1],document(mode=4)[0],document(depth=32)[0]]:
            source.write_bytes(payload);result=self.run_files([source]);self.assertEqual(result.returncode,1,result.stdout)
            self.assertFalse(source.with_suffix('.png').exists())
    def test_destination_symlink(self):
        source=self.folder/'name.psd';source.write_bytes(document()[0])
        other=self.folder/'untouched';other.write_bytes(b'unchanged')
        target=source.with_suffix('.png');target.symlink_to(other)
        self.assertEqual(self.run_files([source],'replace').returncode,0)
        self.assertEqual(other.read_bytes(),b'unchanged');self.assertFalse(target.is_symlink());png(target)
    def test_concurrent_copies(self):
        source=self.folder/'name.psb';source.write_bytes(document(version=2)[0]);source.with_suffix('.png').write_bytes(b'original destination')
        with ThreadPoolExecutor(max_workers=8) as pool:
            results=list(pool.map(lambda _:self.run_files([source]),range(8)))
        self.assertTrue(all(result.returncode==0 for result in results))
        self.assertEqual(len(list(self.folder.glob('name copy*.png'))),8)
        self.assertEqual(source.with_suffix('.png').read_bytes(),b'original destination')
    def test_zip_corruption(self):
        source=self.folder/'bad.psb'
        for compression in [2,3]:
            payload,_=document(version=2,compression=compression)
            source.write_bytes(payload[:-1]);result=self.run_files([source]);self.assertEqual(result.returncode,1)
            self.assertFalse(source.with_suffix('.png').exists())
    def test_rle_repeat(self):
        data,_=document(width=3,height=1)
        # Replace raw payload with three PackBits repeat packets.
        data=data[:-11]+b'\0\1'+b'\0\2'*3+bytes([254,32,254,64,254,128])
        source=self.folder/'repeat.psd';source.write_bytes(data)
        result=self.run_files([source]);self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(png(source.with_suffix('.png'))[1],b'\0'+bytes([32,64,128])*3)

if __name__=='__main__':unittest.main()
