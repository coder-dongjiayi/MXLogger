#!/usr/bin/env python3
"""Build an isolated Flutter OHOS app against the central OHPM HAR; optionally run twice."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import uuid
import zipfile

import verify_ohos_poc as poc

ROOT = Path(__file__).resolve().parent.parent
MARKER = 'MXLOGGER_FLUTTER_OHOS '
IGNORE = shutil.ignore_patterns('build', '.dart_tool', '.hvigor', '.cxx', 'oh_modules',
    'node_modules', 'local.properties', 'oh-package-lock.json5', 'BuildProfile.ets',
    'build-profile.json5', '.idea', '.DS_Store')


def run(command, *, cwd, env, log):
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open('w') as output:
        process = subprocess.run([str(x) for x in command], cwd=cwd, env=env,
            stdout=output, stderr=subprocess.STDOUT, timeout=900)
    if process.returncode:
        # Flutter crash reports may append a long doctor report and URL. Keep
        # diagnostics focused on the build and leave full logs in the fixture.
        lines = log.read_text().split('Oops; flutter has exited unexpectedly:', 1)[0].splitlines()
        raise RuntimeError('Command failed; see ' + str(log) + '\n' +
            '\n'.join(lines[-45:]))


def prepare(args, out):
    plugin = out / 'flutter_mxlogger'
    source = ROOT / 'platform/flutter_mxlogger'
    plugin.mkdir()
    for name in ('lib', 'ohos'):
        shutil.copytree(source / name, plugin / name, ignore=IGNORE)
    shutil.copy2(source / 'ohos/build-profile.json5', plugin / 'ohos/build-profile.json5')
    shutil.copy2(source / 'pubspec.yaml', plugin / 'pubspec.yaml')
    shutil.copy2(source / 'LICENSE', plugin / 'LICENSE')
    app = out / 'app'
    app.mkdir()
    shutil.copytree(source / 'example/ohos', app / 'ohos', ignore=IGNORE)
    shutil.copy2(source / 'example/ohos/build-profile.template.json5', app / 'ohos/build-profile.json5')
    shutil.copy2(source / 'example/ohos/entry/build-profile.json5', app / 'ohos/entry/build-profile.json5')
    (app / 'lib').mkdir()
    shutil.copy2(source / 'example/lib/ohos_smoke.dart', app / 'lib/ohos_smoke.dart')
    (app / 'pubspec.yaml').write_text('''name: mxlogger_ohos_verify
publish_to: none
environment:
  sdk: ">=3.8.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
  flutter_mxlogger:
    path: ../flutter_mxlogger
flutter:
  uses-material-design: true
''')
    if args.demo:
        shutil.copytree(source / 'example/lib', app / 'lib', dirs_exist_ok=True)
        shutil.copytree(source / 'example/assets', app / 'assets')
        with (app / 'pubspec.yaml').open('a') as pubspec:
            pubspec.write('''  assets:
    - assets/mxlogger_logo.png
''')
        # These are the interactive Demo's only additional runtime dependencies.
        text = (app / 'pubspec.yaml').read_text().replace('  flutter_mxlogger:\n',
            '  path_provider: ^2.0.11\n  cupertino_icons: ^1.0.8\n  flutter_mxlogger:\n')
        (app / 'pubspec.yaml').write_text(text)
    project = app / 'ohos'
    profile = json.loads((project / 'build-profile.json5').read_text())
    bundle_path = project / 'AppScope/app.json5'
    bundle = json.loads(bundle_path.read_text())
    if args.signing_project:
        # Signing stays in the ignored fixture and is never printed or packed into the plugin.
        signing = json.loads((args.signing_project / 'build-profile.json5').read_text())
        profile['app']['signingConfigs'] = signing['app']['signingConfigs']
        config = signing['app']['products'][0]['signingConfig']
        profile['app']['products'][0]['signingConfig'] = config
        original = json.loads((args.signing_project / 'AppScope/app.json5').read_text())
        # Preserve versionCode so restoring the original is not a package downgrade.
        for key in ('bundleName', 'versionCode', 'versionName'):
            bundle['app'][key] = original['app'][key]
    (project / 'build-profile.json5').write_text(json.dumps(profile, indent=2))
    bundle_path.write_text(json.dumps(bundle, indent=2))
    # Flutter rewrites AppScope's version from pubspec while building the HAP.
    with (app / 'pubspec.yaml').open('a') as pubspec:
        pubspec.write(f"version: {bundle['app']['versionName']}+{bundle['app']['versionCode']}\n")
    entry = project / 'entry/src/main/ets'
    shutil.copy2(ROOT / 'scripts/fixtures/flutter_ohos/VerificationBridge.ets', entry / 'VerificationBridge.ets')
    (entry / 'entryability/EntryAbility.ets').write_text('''import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { VerificationBridge } from '../VerificationBridge';
export default class EntryAbility extends FlutterAbility {
  private verification: VerificationBridge | null = null;
  configureFlutterEngine(engine: FlutterEngine): void {
    super.configureFlutterEngine(engine);
    GeneratedPluginRegistrant.registerWith(engine);
    this.verification = new VerificationBridge(engine);
  }
}
''')
    manifest_path = project / 'entry/oh-package.json5'
    manifest = json.loads(manifest_path.read_text())
    manifest.setdefault('dependencies', {})['@djy/mxlogger'] = '2.3.1'
    manifest_path.write_text(json.dumps(manifest, indent=2))
    return app, bundle['app']['bundleName']


def device(args, out, hap, bundle):
    hdc = args.deveco / 'sdk/default/openharmony/toolchains/hdc'
    def call(*command):
        result = subprocess.run([str(hdc), '-t', args.device, *map(str, command)],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding='utf-8',
            errors='replace', timeout=45)
        if result.returncode:
            raise RuntimeError(result.stdout)
        return result.stdout
    installed = call('install', '-r', hap)
    if 'install bundle successfully' not in installed:
        raise RuntimeError('Device installation was not confirmed: ' + installed)
    launches = []
    try:
        for _ in range(2):
            call('shell', 'aa', 'force-stop', bundle)
            old_logs = call('shell', 'hilog', '-x', '-T', 'XComFlutterOHOS_Native')
            seen = {item['pid'] for item in parse_reports(old_logs)}
            start = call('shell', 'aa', 'start', '-b', bundle, '-a', 'EntryAbility')
            if 'start ability successfully' not in start:
                raise RuntimeError(start)
            deadline = time.monotonic() + 45
            report = None
            while time.monotonic() < deadline:
                logs = call('shell', 'hilog', '-x', '-T', 'XComFlutterOHOS_Native')
                (out / 'device-hilog.txt').write_text(logs)
                reports = [item for item in parse_reports(logs) if item['pid'] not in seen]
                if reports:
                    report = reports[-1]
                    break
                time.sleep(1)
            if not report or not report.get('passed'):
                raise RuntimeError('Flutter device verification failed: ' + json.dumps(report, ensure_ascii=False))
            launches.append(report)
        if launches[0]['pid'] == launches[1]['pid']:
            raise RuntimeError('Expected two distinct app processes')
        for encrypted in (False, True):
            a, b = [next(mode for mode in launch['modes'] if mode['encrypted'] == encrypted)
                    for launch in launches]
            if b['previousCount'] != a['readBackCount'] or a['loggerToken'] != b['loggerToken']:
                raise RuntimeError('Separate-process persistence failed')
        (out / 'device-report.json').write_text(json.dumps({'launches': launches}, ensure_ascii=False, indent=2))
        print('PASS: Flutter FFI, plain/AES, ArkTS token sharing, isolate, lifecycle and two-process persistence', flush=True)
    finally:
        if args.restore_hap:
            restored = call('install', '-r', args.restore_hap)
            if 'install bundle successfully' not in restored:
                raise RuntimeError('Could not restore the original Demo: ' + restored)
            print('Restored original Demo HAP', flush=True)


def parse_reports(logs):
    reports = []
    for line in logs.splitlines():
        if MARKER in line:
            reports.append(json.loads(line.split(MARKER, 1)[1]))
    return reports


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter', type=Path, default=os.environ.get('FLUTTER_OHOS_BIN'),
                        help='HarmonyOS Flutter bin/flutter (or FLUTTER_OHOS_BIN)')
    parser.add_argument('--deveco', type=Path, default=Path('/Applications/DevEco-Studio.app/Contents'))
    parser.add_argument('--device', help='HDC target; installs and runs the verification app twice')
    parser.add_argument('--signing-project', type=Path,
                        help='Reuse this DevEco project signing config AND bundle ID in the isolated app')
    parser.add_argument('--restore-hap', type=Path, help='Restore this signed Demo HAP after device verification')
    parser.add_argument('--demo', action='store_true', help='Build the interactive lib/main.dart Demo instead of the smoke entry')
    args = parser.parse_args()
    if not args.flutter or not args.flutter.is_file():
        parser.error('Specify --flutter /path/to/harmonyos/flutter/bin/flutter')
    if args.signing_project and args.device and not args.restore_hap:
        parser.error('--restore-hap is required when reusing an existing device app identity')
    if args.restore_hap and not args.restore_hap.is_file():
        parser.error('--restore-hap must be an existing HAP')
    if args.demo and args.device:
        parser.error('--device runs the smoke entry; use --demo for a build-only interactive Demo check')
    args.flutter = args.flutter.resolve()
    args.deveco = args.deveco.resolve()
    if args.signing_project:
        args.signing_project = args.signing_project.resolve()
    if args.restore_hap:
        args.restore_hap = args.restore_hap.resolve()
    out = ROOT / 'build/flutter-ohos' / (time.strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:6])
    out.mkdir(parents=True)
    print('Verification artifacts: ' + str(out), flush=True)
    app, bundle = prepare(args, out)
    poc.OUTPUT = out
    env = poc.environment(args.deveco)
    env['PATH'] = os.pathsep.join(str(args.deveco / part) for part in
        ('tools/node/bin', 'tools/ohpm/bin', 'tools/hvigor/bin', 'sdk/default/openharmony/toolchains')) + os.pathsep + env['PATH']
    env['PUB_HOSTED_URL'] = os.environ.get('PUB_HOSTED_URL', 'https://pub.dev')
    env['CI'] = 'true'
    command = [args.flutter, '--suppress-analytics', '--no-version-check']
    run(command + ['pub', 'get'], cwd=app, env=env, log=out / 'pub-get.log')
    target = 'lib/main.dart' if args.demo else 'lib/ohos_smoke.dart'
    signing_flags = [] if args.signing_project else ['--no-codesign']
    run(command + ['build', 'hap', '--debug', '--target-platform', 'ohos-arm64',
         '-t', target, '--no-pub'] + signing_flags, cwd=app, env=env, log=out / 'build.log')
    haps = list((app / 'ohos/entry/build/default/outputs/default').glob('entry-default-*.hap'))
    if not haps:
        raise RuntimeError('Flutter build did not produce a HAP')
    hap = max(haps, key=lambda path: ('signed' in path.name and 'unsigned' not in path.name, path.stat().st_mtime_ns))
    with zipfile.ZipFile(hap) as package:
        if package.namelist().count('libs/arm64-v8a/libmxlogger.so') != 1:
            raise RuntimeError('Expected exactly one MXLogger native library in the Flutter app')
    if list(app.rglob('*.cpp.o')) or list(app.rglob('CMakeCache.txt')):
        raise RuntimeError('Consumer unexpectedly compiled native source')
    report = {'bundleName': bundle, 'hap': str(hap), 'hapSha256': hashlib.sha256(hap.read_bytes()).hexdigest(),
              'package': '@djy/mxlogger@2.3.1', 'compiledCore': False, 'buildPassed': True, 'target': target}
    (out / 'build-report.json').write_text(json.dumps(report, indent=2))
    print('PASS: Flutter HAP built from the central OHPM HAR, without compiling Core', flush=True)
    if args.device:
        device(args, out, hap, bundle)


if __name__ == '__main__':
    main()
