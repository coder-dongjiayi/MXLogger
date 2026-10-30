#!/usr/bin/env python3
"""Build/test Flutter Android against the checkout Java/JNI/Core project."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from check_local_core import ROOT, check_cmake, core_version, write_report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter', default=shutil.which('flutter'))
    parser.add_argument('--device', default='emulator-5554')
    parser.add_argument('--build-only', action='store_true', help='Compile locally without installing; CI must run the device tests')
    args = parser.parse_args()
    if not args.flutter:
        parser.error('Flutter is required')
    directory = ROOT / 'build/flutter-android-tests'
    directory.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix='run-', dir=directory))
    plugin = stage / 'flutter_mxlogger'
    shutil.copytree(ROOT / 'platform/flutter_mxlogger', plugin,
                    ignore=shutil.ignore_patterns('build', '.dart_tool', '.gradle', '.cxx', 'Pods',
                        '.symlinks', 'ephemeral', '.build', '.swiftpm', 'FlutterFramework', '*.dylib', 'local.properties'))
    example = plugin / 'example'
    env = os.environ.copy()
    env['MXLOGGER_LOCAL_NATIVE'] = '1'
    env['MXLOGGER_LOCAL_NATIVE_ROOT'] = str(ROOT)

    def run(name, command, cwd=example):
        print(f'>> {name}', flush=True)
        with (stage / f'{name}.log').open('w') as log:
            result = subprocess.run([str(arg) for arg in command], cwd=cwd, env=env,
                                    stdout=log, stderr=subprocess.STDOUT)
        if result.returncode:
            print('\n'.join((stage / f'{name}.log').read_text(errors='replace').splitlines()[-80:]), flush=True)
            raise RuntimeError(f'{name} failed; see {stage}')

    run('pub', [args.flutter, 'pub', 'get'])
    version_flag = f'--dart-define=MXLOGGER_EXPECTED_CORE_VERSION={core_version()}'
    target = 'integration_test/mobile_logger_test.dart'
    if args.build_only:
        run('build', [args.flutter, 'build', 'apk', '--debug', '--target-platform', 'android-arm64', '-t', target, version_flag, '--no-pub'])
    else:
        run('device-tests', [args.flutter, 'test', target, '-d', args.device, version_flag, '--no-pub', '--reporter', 'expanded'])
    run('resolved-dependencies', ['bash', 'gradlew', '--no-daemon', '--console=plain',
                                ':flutter_mxlogger:verifyLocalMXLoggerDependency'], cwd=example / 'android')
    native = ROOT / 'platform/Android/MXLogger/mxlogger'
    caches = list((native / '.cxx').rglob('CMakeCache.txt'))
    if not caches:
        raise RuntimeError('No native Core build configuration found for Flutter Android')
    evidence = [check_cmake(p) for p in caches]
    report = example / 'build/flutter_mxlogger/reports/local-core.json'
    if not report.exists():
        raise RuntimeError(f'Resolved Gradle dependency report is missing: {report}')
    evidence.append({'kind': 'gradle', **json.loads(report.read_text())})
    write_report(stage / 'local-core.json', evidence)
    print(f'>> Flutter Android {"build only" if args.build_only else "API tests"} passed; reports: {stage}')
    # Retain logs/provenance, not a second distributable or several GB of caches.
    shutil.rmtree(plugin)


if __name__ == '__main__':
    main()
