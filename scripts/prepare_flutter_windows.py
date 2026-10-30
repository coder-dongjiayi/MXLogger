#!/usr/bin/env python3
"""Stage prebuilt x64 DLLs from a local MXLogger.Native nupkg (works on macOS).

No compilation, network or NuGet client is needed. Prepare windows/bin before
publishing the Flutter package, so pub users receive the DLLs automatically.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import tempfile
import zipfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
PLUGIN = ROOT / 'platform/flutter_mxlogger'
VERSION = '2.3.0'
PREFIX = 'build/native/ffi/x64/'


def validate_payload(read):
    manifest = json.loads(read('manifest.json').decode('utf-8-sig'))
    if (manifest.get('core_version'), manifest.get('architecture'), manifest.get('ffi_abi')) != (VERSION, 'x64', 1):
        raise ValueError('Incompatible Core version, Windows architecture or FFI ABI')
    files = {'manifest.json': json.dumps(manifest, indent=2).encode() + b'\n'}
    for configuration in ('Debug', 'Release'):
        name = f'{configuration}/mxlogger_ffi.dll'
        dll = read(name)
        if hashlib.sha256(dll).hexdigest() != manifest['sha256'][configuration]:
            raise ValueError(f'{configuration} DLL hash mismatch')
        if len(dll) < 64 or dll[:2] != b'MZ':
            raise ValueError(f'{configuration} is not a Windows PE file')
        offset = struct.unpack_from('<I', dll, 0x3c)[0]
        if (offset + 24 > len(dll) or dll[offset:offset + 4] != b'PE\0\0' or
                struct.unpack_from('<H', dll, offset + 4)[0] != 0x8664 or
                not struct.unpack_from('<H', dll, offset + 22)[0] & 0x2000):
            raise ValueError(f'{configuration} is not an x64 DLL')
        files[name] = dll
    return files


def prepare(package, plugin):
    with zipfile.ZipFile(package) as archive:
        nuspecs = [n for n in archive.namelist() if '/' not in n and n.endswith('.nuspec')]
        if len(nuspecs) != 1:
            raise ValueError('Expected one NuGet package manifest')
        spec = ET.fromstring(archive.read(nuspecs[0]))
        if (spec.findtext('.//{*}metadata/{*}id'), spec.findtext('.//{*}metadata/{*}version')) != ('MXLogger.Native', VERSION):
            raise ValueError(f'Expected MXLogger.Native {VERSION}')
        # Read only known members; never extract arbitrary archive paths.
        files = validate_payload(lambda name: archive.read(PREFIX + name))
    parent = plugin / 'windows/bin'
    parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=parent) as temporary:
        staged = Path(temporary) / 'x64'
        for name, content in files.items():
            target = staged / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
        destination = parent / 'x64'
        if destination.exists():
            shutil.rmtree(destination)
        shutil.move(str(staged), destination)
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', type=Path, help='Local MXLogger.Native.2.3.0.nupkg')
    parser.add_argument('--plugin', type=Path, default=PLUGIN, help='Flutter package directory')
    parser.add_argument('--check', action='store_true', help='Verify already-staged binaries')
    args = parser.parse_args()
    if args.check:
        payload = args.plugin / 'windows/bin/x64'
        validate_payload(lambda name: (payload / name).read_bytes())
        print(f'PASS: {payload} (Core {VERSION}, x64, Debug + Release)')
    elif args.package:
        print(f'PASS: prepared {prepare(args.package, args.plugin)}')
    else:
        parser.error('Provide --package <nupkg> or --check')


if __name__ == '__main__':
    main()
