#!/usr/bin/env python3
"""Build a Release HAR, consume it in an isolated app, and run device contracts."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import tarfile
import time
import uuid
import zipfile
import verify_ohos_poc as poc

ROOT = poc.ROOT
SOURCE = ROOT / 'platform/OHOS/mxlogger/src/main/cpp'
OUTPUT = ROOT / 'build/ohos-sdk'


def host(deveco):
    build = OUTPUT / 'host-asan'
    flags = '-fsanitize=address -fno-omit-frame-pointer'
    poc.run(['cmake', '-S', SOURCE, '-B', build, '-DCMAKE_BUILD_TYPE=Debug',
             '-DMXLOGGER_OHOS_BUILD_TESTS=ON', '-DCMAKE_CXX_FLAGS=' + flags,
             '-DCMAKE_C_FLAGS=' + flags, '-DCMAKE_SHARED_LINKER_FLAGS=-fsanitize=address',
             '-DCMAKE_EXE_LINKER_FLAGS=-fsanitize=address'], log=OUTPUT / 'host-configure.log')
    poc.run(['cmake', '--build', build, '--parallel', '4'], log=OUTPUT / 'host-build.log')
    env = dict(os.environ)
    env['ASAN_OPTIONS'] = 'detect_leaks=0:halt_on_error=1'  # macOS ASan does not implement LSan.
    poc.run(['ctest', '--test-dir', build, '--output-on-failure'], env=env,
            log=OUTPUT / 'host-tests.log')
    print('PASS: managed bridge contracts and write/destroy races under AddressSanitizer', flush=True)


def prepare(project, deveco):
    modules = project / 'node_modules/@ohos'
    modules.mkdir(parents=True, exist_ok=True)
    for name in ('hvigor', 'hvigor-ohos-plugin'):
        destination = modules / name
        if not destination.exists():
            destination.symlink_to(deveco / 'tools/hvigor' / name, target_is_directory=True)
    (project / 'local.properties').write_text('sdk.dir=' + str(deveco / 'sdk') + '\n')
    env = poc.environment(deveco)
    env['NODE_PATH'] = str(project / 'node_modules')
    poc.run([deveco / 'tools/node/bin/node', deveco / 'tools/ohpm/bin/pm-cli.js', 'install',
             '--all', '--cache', OUTPUT / 'ohpm-cache'], cwd=project, env=env,
            log=project / 'build/ohpm-install.log')
    return env


def hvigor(project, deveco, module, task, mode):
    (project / 'build').mkdir(exist_ok=True)
    env = prepare(project, deveco)
    poc.run([deveco / 'tools/node/bin/node', deveco / 'tools/hvigor/hvigor/bin/hvigor.js',
             '--mode', 'module', '-p', 'product=default', '-p', 'module=' + module + '@default',
             '-p', 'buildMode=' + mode, task, '--no-daemon'], cwd=project, env=env,
            log=project / ('build/' + task + '-' + mode + '.log'))


def build_har(deveco):
    profile = poc.PROJECT / 'build-profile.json5'
    if not profile.exists():
        shutil.copy2(poc.PROJECT / 'build-profile.template.json5', profile)
    # Register a new module while preserving the user's private IDE signing configuration.
    data = json.loads(profile.read_text())
    if not any(module['name'] == 'mxlogger' for module in data['modules']):
        data['modules'].insert(0, {'name': 'mxlogger', 'srcPath': './mxlogger',
                                  'targets': [{'name': 'default', 'applyToProducts': ['default']}]})
        profile.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    hvigor(poc.PROJECT, deveco, 'mxlogger', 'assembleHar', 'release')
    candidates = list((poc.PROJECT / 'mxlogger/build/default/outputs/default').glob('*.har'))
    if not candidates:
        raise RuntimeError('HAR was not generated')
    har = OUTPUT / 'mxlogger-0.1.0.har'
    shutil.copy2(max(candidates, key=lambda path: path.stat().st_mtime_ns), har)
    with tarfile.open(har) as archive:
        names = archive.getnames()
        required = set(re.findall(r'\b((?:flutter_mxlogger|mxlogger_ohos)_\w+)\s*\(',
            (ROOT / 'Core/ffi/mxlogger_ffi.h').read_text() + (SOURCE / 'mxlogger_ohos.h').read_text()))
        required.discard('flutter_mxlogger_default_directory')
        for abi in ('arm64-v8a', 'x86_64'):
            matches = [name for name in names if name.endswith('/libs/' + abi + '/libmxlogger.so')]
            if len(matches) != 1:
                raise RuntimeError('HAR missing native library for ' + abi)
            directory = OUTPUT / 'har-libs' / abi
            directory.mkdir(parents=True, exist_ok=True)
            library = directory / 'libmxlogger.so'
            library.write_bytes(archive.extractfile(matches[0]).read())
            symbols = poc.run([deveco / 'sdk/default/openharmony/native/llvm/bin/llvm-nm',
                               '-D', '--defined-only', library])
            exported = {line.split()[-1] for line in symbols.splitlines() if line.split()}
            if required - exported:
                raise RuntimeError('HAR missing C ABI exports for ' + abi + ': ' + ', '.join(sorted(required-exported)))
            (directory / 'exports.txt').write_text(symbols)
        if not any(name.endswith(('/Index.ets', '/Index.d.ets')) for name in names):
            raise RuntimeError('HAR missing ArkTS public API')
        if any('/.cxx/' in name or '/.hvigor/' in name for name in names):
            raise RuntimeError('HAR contains private build caches')
        (OUTPUT / 'har-contents.txt').write_text('\n'.join(names) + '\n')
    print('PASS: Release HAR contains ArkTS API and ARM64/x86_64 native libraries', flush=True)
    return har


def consumer(deveco, har):
    project = OUTPUT / ('consumer-' + uuid.uuid4().hex[:8])
    project.mkdir()
    for name in ('AppScope', 'hvigor', 'entry'):
        shutil.copytree(poc.PROJECT / name, project / name,
                        ignore=shutil.ignore_patterns('build', '.cxx', '.hvigor', 'oh_modules', 'node_modules'))
    for name in ('hvigorfile.ts', 'oh-package.json5'):
        shutil.copy2(poc.PROJECT / name, project / name)
    profile = json.loads((poc.PROJECT / 'build-profile.json5').read_text())
    profile['modules'] = [module for module in profile['modules'] if module['name'] == 'entry']
    (project / 'build-profile.json5').write_text(json.dumps(profile, ensure_ascii=False, indent=2))
    (project / 'libs').mkdir()
    shutil.copy2(har, project / 'libs/mxlogger.har')
    manifest = json.loads((project / 'entry/oh-package.json5').read_text())
    manifest['dependencies'] = {'@mxlogger/mxlogger': 'file:../libs/mxlogger.har'}
    (project / 'entry/oh-package.json5').write_text(json.dumps(manifest, indent=2))
    hvigor(project, deveco, 'entry', 'assembleHap', 'debug')
    if list(project.rglob('CMakeCache.txt')) or list(project.rglob('*.cpp.o')):
        raise RuntimeError('isolated HAR consumer unexpectedly compiled C++')
    outputs = project / 'entry/build/default/outputs/default'
    hap = max(outputs.glob('entry-default-*.hap'), key=lambda path: path.stat().st_mtime_ns)
    with zipfile.ZipFile(hap) as package:
        for abi in ('arm64-v8a', 'x86_64'):
            if package.namelist().count('libs/' + abi + '/libmxlogger.so') != 1:
                raise RuntimeError('consumer did not package exactly one native library per architecture')
    demo_hap = OUTPUT / 'mxlogger-demo.hap'
    shutil.copy2(hap, demo_hap)
    report = {'harSha256': hashlib.sha256(har.read_bytes()).hexdigest(), 'consumerProject': str(project),
              'consumerHap': str(hap), 'demoHap': str(demo_hap), 'compiledCore': False}
    (OUTPUT / 'consumer-report.json').write_text(json.dumps(report, indent=2))
    print('PASS: isolated app built using only the HAR, without compiling Core', flush=True)
    return hap


def device(deveco, target, hap):
    poc.device_check(deveco, target, hap)
    target_name = re.sub(r'[^A-Za-z0-9_.-]', '_', target)
    report_file = OUTPUT / ('device-report-' + target_name + '.json')
    data = json.loads(report_file.read_text())
    pids = {launch[0]['pid'] for launch in data['launches']}
    hdc = [deveco / 'sdk/default/openharmony/toolchains/hdc', '-t', target]
    checks = []
    captured = (Path(data['exportDirectory']).parent / 'device-hilog.txt').read_text()
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        logs = captured + '\n' + poc.run(hdc + ['shell', 'hilog', '-x', '-T', 'MXLoggerPOC'])
        candidates = [json.loads(line.split('MXLOGGER_OHOS_SDK ', 1)[1])
                  for line in logs.splitlines() if 'MXLOGGER_OHOS_SDK ' in line]
        checks = list({item['pid']: item for item in candidates if item.get('pid') in pids}.values())
        if len(checks) == 2:
            break
        time.sleep(1)
    if len(checks) != 2 or not all(item['passed'] and item['checks'] >= 30 and item['workerRecords'] == 64 for item in checks):
        raise RuntimeError('both app processes must pass the public SDK and Worker contracts')
    data['sdkContracts'] = checks
    report_file.write_text(json.dumps(data, indent=2))
    run_dir = Path(data['exportDirectory']).parent
    (run_dir / 'device-report.json').write_text(json.dumps(data, indent=2))
    print('PASS: public HAR API, shared state, stale generation protection, cleanup and Worker on device', flush=True)
    print('Report: ' + str(report_file), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--deveco', type=Path, default=Path('/Applications/DevEco-Studio.app/Contents'))
    parser.add_argument('--host', action='store_true')
    parser.add_argument('--device', help='HDC target; runs the isolated HAR consumer on the device')
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    poc.OUTPUT = OUTPUT
    if args.host:
        host(args.deveco)
    har = build_har(args.deveco)
    hap = consumer(args.deveco, har)
    if args.device:
        device(args.deveco, args.device, hap)


if __name__ == '__main__':
    main()
