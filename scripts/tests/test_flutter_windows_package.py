"""Cross-platform packaging checks. PE fixtures are headers, not runnable DLLs.

Windows CI separately loads the actual compiled DLL through Dart/Flutter.
"""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('prepare', ROOT / 'scripts/prepare_flutter_windows.py')
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


def pe_header(machine=0x8664):
    data = bytearray(128)
    data[:2] = b'MZ'
    struct.pack_into('<I', data, 0x3c, 64)
    data[64:68] = b'PE\0\0'
    struct.pack_into('<H', data, 68, machine)
    struct.pack_into('<H', data, 86, 0x2000)
    return bytes(data)


class WindowsPackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='mxlogger package ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.plugin = self.root / 'plugin'
        dll = pe_header()
        self.files = {f'{c}/mxlogger_ffi.dll': dll for c in ('Debug', 'Release')}
        self.manifest = {
            'core_version': '2.3.0', 'ffi_abi': 1, 'architecture': 'x64',
            'sha256': {c: hashlib.sha256(dll).hexdigest() for c in ('Debug', 'Release')},
        }

    def package(self, manifest=None, files=None, package_id='MXLogger.Native', version='2.3.0'):
        path = self.root / 'sdk.nupkg'
        with zipfile.ZipFile(path, 'w') as archive:
            archive.writestr('MXLogger.Native.nuspec',
                             '<package xmlns="http://schemas.microsoft.com/packaging/2013/05/nuspec.xsd">'
                             f'<metadata><id>{package_id}</id><version>{version}</version></metadata></package>')
            archive.writestr(prepare.PREFIX + 'manifest.json', json.dumps(manifest or self.manifest))
            for name, data in (files or self.files).items():
                archive.writestr(prepare.PREFIX + name, data)
            archive.writestr('../outside.txt', 'must not be extracted')
        return path

    def test_prepare_and_validate_without_core_checkout(self):
        destination = prepare.prepare(self.package(), self.plugin)
        files = prepare.validate_payload(lambda name: (destination / name).read_bytes())
        self.assertEqual(set(files), {'manifest.json', *self.files})
        self.assertFalse((self.root / 'outside.txt').exists())
        self.assertFalse((self.plugin / 'windows/core').exists())

    def test_wrong_package_and_version_rejected(self):
        for package_id, version in [('Other', '2.3.0'), ('MXLogger.Native', '2.2.0')]:
            with self.subTest(package_id=package_id, version=version), self.assertRaises(ValueError):
                prepare.prepare(self.package(package_id=package_id, version=version), self.plugin)

    def test_version_abi_architecture_and_hash_rejected(self):
        for key, value in [('core_version', '2.2.0'), ('ffi_abi', 2), ('architecture', 'arm64')]:
            manifest = copy.deepcopy(self.manifest)
            manifest[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                prepare.prepare(self.package(manifest=manifest), self.plugin)
        files = dict(self.files)
        files['Release/mxlogger_ffi.dll'] += b'corruption'
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            prepare.prepare(self.package(files=files), self.plugin)

    def test_wrong_pe_machine_rejected_even_with_matching_hash(self):
        files = {name: pe_header(0xaa64) for name in self.files}
        manifest = copy.deepcopy(self.manifest)
        manifest['sha256'] = {c: hashlib.sha256(pe_header(0xaa64)).hexdigest() for c in ('Debug', 'Release')}
        with self.assertRaisesRegex(ValueError, 'not an x64 DLL'):
            prepare.prepare(self.package(manifest, files), self.plugin)

    def test_missing_binary_preserves_previously_prepared_payload(self):
        destination = prepare.prepare(self.package(), self.plugin)
        original = (destination / 'Release/mxlogger_ffi.dll').read_bytes()
        with self.assertRaises(KeyError):
            prepare.prepare(self.package(files={'Debug/mxlogger_ffi.dll': pe_header()}), self.plugin)
        self.assertEqual((destination / 'Release/mxlogger_ffi.dll').read_bytes(), original)

    @unittest.skipUnless(shutil.which('cmake'), 'CMake is required')
    def test_flutter_cmake_selects_debug_release_profile_and_rejects_bad_hash(self):
        prepare.prepare(self.package(), self.plugin)
        shutil.copyfile(ROOT / 'platform/flutter_mxlogger/windows/CMakeLists.txt',
                        self.plugin / 'windows/CMakeLists.txt')
        # A source-free mock host exercises Flutter's bundled-library contract.
        host = self.root / 'host'
        host.mkdir()
        (host / 'CMakeLists.txt').write_text(
            'cmake_minimum_required(VERSION 3.19)\nproject(host LANGUAGES NONE)\n'
            f'add_subdirectory("{self.plugin.as_posix()}/windows" plugin)\n'
            'file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/bundled-$<CONFIG>.txt" '
            'CONTENT "${flutter_mxlogger_bundled_libraries}")\n')
        for mode, expected in [('Debug', 'Debug'), ('Release', 'Release'), ('Profile', 'Release')]:
            build = self.root / mode
            result = subprocess.run(['cmake', '-S', str(host), '-B', str(build), f'-DCMAKE_BUILD_TYPE={mode}',
                                     '-DCMAKE_CONFIGURATION_TYPES=Debug;Release;Profile',
                                     '-DFLUTTER_TARGET_PLATFORM=windows-x64'], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((build / f'bundled-{mode}.txt').read_text(),
                             (self.plugin / f'windows/bin/x64/{expected}/mxlogger_ffi.dll').as_posix())
        (self.plugin / 'windows/bin/x64/Release/mxlogger_ffi.dll').write_bytes(b'corrupt')
        result = subprocess.run(['cmake', '-S', str(host), '-B', str(self.root / 'bad')],
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('hash mismatch', result.stderr)


if __name__ == '__main__':
    unittest.main()
