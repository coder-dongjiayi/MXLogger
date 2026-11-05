#!/usr/bin/env python3
"""Build the OHOS POC and verify two app processes on an emulator or signed device.

No accounts, signatures or system-wide environment settings are modified.
Unsigned installation is only attempted on devices identifying as emulators.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
import uuid
import zipfile

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / 'platform/OHOS'
OUTPUT = ROOT / 'build/ohos-poc'
BUNDLE = 'com.mxlogger.ohos.poc'
MARKER = 'MXLOGGER_OHOS_POC '


def run(command, *, cwd=ROOT, env=None, log=None):
    result = subprocess.run([str(x) for x in command], cwd=cwd, env=env,
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            timeout=180)
    if log:
        Path(log).write_text(result.stdout)
    if result.returncode:
        raise RuntimeError('\n'.join(result.stdout.splitlines()[-55:]))
    return result.stdout


def parse_reports(output):
    reports = []
    for line in output.splitlines():
        if MARKER in line:
            reports.append(json.loads(line.split(MARKER, 1)[1]))
    return reports


def verify_pair(first, second):
    if len(first) != 2 or len(second) != 2:
        raise RuntimeError('expected plain + encrypted reports from both processes')
    for encrypted in (False, True):
        a = next(x for x in first if x['encrypted'] == encrypted)
        b = next(x for x in second if x['encrypted'] == encrypted)
        if not all(x['passed'] and x['sharedCore'] and
                   x['readBackCount'] == x['previousCount'] + 2 for x in (a, b)):
            raise RuntimeError('write/reopen or shared-Core check failed')
        if a['pid'] == b['pid'] or b['previousCount'] != a['readBackCount']:
            raise RuntimeError('second process did not preserve the first process records')
        if a['loggerToken'] != b['loggerToken'] or a['coreVersion'] != b['coreVersion']:
            raise RuntimeError('logger identity/version changed between processes')


def host_check():
    build = OUTPUT / 'host'
    run(['cmake', '-S', PROJECT / 'native', '-B', build, '-DCMAKE_BUILD_TYPE=Release'],
        log=OUTPUT / 'host-configure.log')
    run(['cmake', '--build', build, '--parallel', '4'], log=OUTPUT / 'host-build.log')
    directory = OUTPUT / ('host-logs-' + uuid.uuid4().hex[:8])
    launches = [[], []]
    for i in range(2):
        for mode in ('plain', 'encrypted'):
            launches[i] += parse_reports(run([build / 'mxlogger_poc_runner', directory, mode]))
    verify_pair(*launches)
    (OUTPUT / 'host-report.json').write_text(json.dumps({'launches': launches}, indent=2))
    print('PASS: host shared library, plain/AES and separate-process persistence', flush=True)


def environment(deveco):
    env = dict(os.environ)
    env.update(NODE_HOME=str(deveco / 'tools/node'),
               JAVA_HOME=str(deveco / 'jbr/Contents/Home'),
               DEVECO_SDK_HOME=str(deveco / 'sdk'),
               HVIGOR_USER_HOME=str(OUTPUT / 'hvigor-home'),
               NODE_PATH=str(PROJECT / 'node_modules'))
    env['PATH'] = str(deveco / 'tools/node/bin') + os.pathsep + env.get('PATH', '')
    return env


def native_build(deveco):
    native = deveco / 'sdk/default/openharmony/native'
    cmake = native / 'build-tools/cmake/bin/cmake'
    for abi in ('arm64-v8a', 'x86_64'):
        build = OUTPUT / ('native-' + abi)
        run([cmake, '-S', PROJECT / 'native', '-B', build, '-G', 'Ninja',
             '-DCMAKE_MAKE_PROGRAM=' + str(native / 'build-tools/cmake/bin/ninja'),
             '-DCMAKE_TOOLCHAIN_FILE=' + str(native / 'build/cmake/ohos.toolchain.cmake'),
             '-DOHOS_ARCH=' + abi, '-DOHOS_STL=c++_static',
             '-DOHOS_COMPATIBLE_SDK_VERSION=12', '-DMXLOGGER_POC_BUILD_RUNNER=OFF',
             '-DCMAKE_BUILD_TYPE=Debug'], log=OUTPUT / (abi + '-configure.log'))
        run([cmake, '--build', build, '--parallel', '4'], log=OUTPUT / (abi + '-build.log'))
        symbols = run([native / 'llvm/bin/llvm-nm', '-D', '--defined-only', build / 'libmxlogger.so'])
        exported = {line.split()[-1] for line in symbols.splitlines() if line.split()}
        header = (ROOT / 'Core/ffi/mxlogger_ffi.h').read_text()
        required = set(re.findall(r'\b(flutter_mxlogger_\w+)\(', header))
        required.discard('flutter_mxlogger_default_directory')  # Windows-only entry.
        if required - exported:
            raise RuntimeError('missing FFI exports: ' + ', '.join(sorted(required - exported)))
        (OUTPUT / (abi + '-exports.txt')).write_text(symbols)
        print('PASS: OHOS ' + abi + ', all shared FFI exports present', flush=True)


def hap_build(deveco):
    profile = PROJECT / 'build-profile.json5'
    if not profile.exists():
        shutil.copy2(PROJECT / 'build-profile.template.json5', profile)
    env = environment(deveco)
    node = deveco / 'tools/node/bin/node'
    modules = PROJECT / 'node_modules/@ohos'
    modules.mkdir(parents=True, exist_ok=True)
    for name in ('hvigor', 'hvigor-ohos-plugin'):
        destination = modules / name
        if not destination.exists():
            destination.symlink_to(deveco / 'tools/hvigor' / name, target_is_directory=True)
    (PROJECT / 'local.properties').write_text('sdk.dir=' + str(deveco / 'sdk') + '\n')
    run([node, deveco / 'tools/ohpm/bin/pm-cli.js', 'install', '--all', '--cache',
         OUTPUT / 'ohpm-cache'], cwd=PROJECT, env=env, log=OUTPUT / 'ohpm-install.log')
    run([node, deveco / 'tools/hvigor/hvigor/bin/hvigor.js', '--mode', 'module',
         '-p', 'product=default', '-p', 'module=entry@default', '-p', 'buildMode=debug',
         'assembleHap', '--no-daemon'], cwd=PROJECT, env=env, log=OUTPUT / 'hap-build.log')
    outputs = PROJECT / 'entry/build/default/outputs/default'
    candidates = list(outputs.glob('entry-default-*.hap'))
    if not candidates:
        raise RuntimeError('Hvigor did not produce a HAP')
    hap = max(candidates, key=lambda path: path.stat().st_mtime_ns)
    with zipfile.ZipFile(hap) as package:
        for abi in ('arm64-v8a', 'x86_64'):
            if f'libs/{abi}/libmxlogger.so' not in package.namelist():
                raise RuntimeError('HAP is missing ' + abi + '/libmxlogger.so')
    shutil.copy2(hap, OUTPUT / hap.name)
    print('PASS: ArkTS + native HAP built, both architectures packaged', flush=True)
    return OUTPUT / hap.name


def validate_hap(hap):
    with zipfile.ZipFile(hap) as package:
        app = json.loads(package.read('module.json'))['app']
        if app.get('bundleName') != BUNDLE:
            raise RuntimeError('the supplied HAP is not the MXLogger POC application')
        if app.get('debug') is not True:
            raise RuntimeError('use a debug HAP to enable app-sandbox log export')


def verify_signature(deveco, hap, output):
    """Use the SDK verifier, without asking for or exposing signing passwords."""
    log = output / 'signature-verification.log'
    try:
        run([deveco / 'jbr/Contents/Home/bin/java', '-jar',
             deveco / 'sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar',
             'verify-app', '-inFile', hap,
             '-outCertChain', output / 'certificate-chain.cer',
             '-outProfile', output / 'debug-profile.p7b'], log=log)
    except RuntimeError:
        raise RuntimeError('physical-device verification requires a signed debug HAP. '
                           'Configure IDE automatic signing or supply --signed-hap PATH; '
                           'details: ' + str(log)) from None
    if not all((output / name).is_file() for name in ('certificate-chain.cer', 'debug-profile.p7b')):
        raise RuntimeError('SDK signature verification did not produce its expected outputs: ' + str(log))


def device_check(deveco, target, hap):
    validate_hap(hap)
    hdc = [deveco / 'sdk/default/openharmony/toolchains/hdc', '-t', target]

    def device(*args):
        output = run(hdc + list(args))
        # HDC may return exit status 0 when the remote command fails.
        if '[Fail]' in output or 'error: failed' in output.lower():
            raise RuntimeError(output)
        return output

    version = device('shell', 'param', 'get', 'const.product.software.version').strip()
    emulator = 'emulator' in version.lower()
    target_name = re.sub(r'[^A-Za-z0-9_.-]', '_', target)
    output = OUTPUT / 'devices' / target_name / uuid.uuid4().hex[:8]
    output.mkdir(parents=True)
    if not emulator:
        verify_signature(deveco, hap, output)
    architecture = device('shell', 'uname', '-m').strip()
    api_version = device('shell', 'param', 'get', 'const.ohos.apiversion').strip()
    install = device('install', '-r', hap)
    if 'install bundle successfully' not in install:
        raise RuntimeError('HAP installation was not confirmed: ' + install)
    launches = []
    for _ in range(2):
        device('shell', 'aa', 'force-stop', BUNDLE)
        previous = device('shell', 'hilog', '-x', '-T', 'MXLoggerPOC')
        seen = {x['pid'] for x in parse_reports(previous)}
        start = device('shell', 'aa', 'start', '-b', BUNDLE, '-a', 'EntryAbility')
        if 'start ability successfully' not in start:
            raise RuntimeError(start)
        deadline = time.monotonic() + 30
        reports = []
        while time.monotonic() < deadline:
            logs = device('shell', 'hilog', '-x', '-T', 'MXLoggerPOC')
            (output / 'device-hilog.txt').write_text(logs)
            reports = [x for x in parse_reports(logs) if x['pid'] not in seen]
            if len(reports) >= 2:
                break
            time.sleep(1)
        if len(reports) != 2:
            raise RuntimeError('app did not produce both successful reports; see ' + str(output / 'device-hilog.txt'))
        launches.append(reports)
    verify_pair(*launches)
    logs = output / 'logs'
    logs.mkdir()
    directory = launches[-1][0]['directory'].lstrip('/')
    transfer = device('file', 'recv', '-b', BUNDLE, directory, logs)
    if 'FileTransfer finish' not in transfer:
        raise RuntimeError('sandbox log export failed: ' + transfer)
    report = {'device': target, 'deviceType': 'emulator' if emulator else 'physical',
              'systemVersion': version, 'architecture': architecture, 'apiVersion': api_version,
              'hapSha256': hashlib.sha256(hap.read_bytes()).hexdigest(),
              'signatureVerified': not emulator, 'launches': launches, 'exportDirectory': str(logs)}
    report_file = output / 'device-report.json'
    report_file.write_text(json.dumps(report, indent=2))
    shutil.copy2(report_file, OUTPUT / ('device-report-' + target_name + '.json'))
    print('PASS: ArkTS → Node-API → FFI/Core, plain + AES, two app processes', flush=True)
    print('Exported logs: ' + str(logs), flush=True)
    print('Device report: ' + str(report_file), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--deveco', type=Path,
                        default=Path('/Applications/DevEco-Studio.app/Contents'))
    parser.add_argument('--host', action='store_true')
    parser.add_argument('--native', action='store_true')
    parser.add_argument('--hap', action='store_true')
    parser.add_argument('--device', help='HDC target; builds and installs the HAP')
    parser.add_argument('--signed-hap', type=Path,
                        help='use an existing signed debug POC HAP instead of building')
    args = parser.parse_args()
    if not any((args.host, args.native, args.hap, args.device)):
        parser.error('select --host, --native, --hap or --device TARGET')
    if args.signed_hap and (not args.device or args.hap):
        parser.error('--signed-hap requires --device and cannot be combined with --hap')
    OUTPUT.mkdir(parents=True, exist_ok=True)
    if args.host:
        host_check()
    if args.native:
        native_build(args.deveco)
    if args.hap or args.device:
        hap = args.signed_hap.resolve() if args.signed_hap else hap_build(args.deveco)
        if args.device:
            device_check(args.deveco, args.device, hap)


if __name__ == '__main__':
    main()
