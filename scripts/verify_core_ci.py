#!/usr/bin/env python3
"""Stage 1: compile and run only the checkout C++ Core unit tests."""
import argparse
import os
from pathlib import Path
import subprocess

from check_local_core import ROOT, check_cmake, write_report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--configuration', choices=['Debug', 'Release'], required=True)
    args = parser.parse_args()
    build = ROOT / 'build/core-ci' / args.configuration
    build.mkdir(parents=True, exist_ok=True)

    def run(name, command):
        print(f'>> {name}: {args.configuration}', flush=True)
        log = build / f'{name}.log'
        with log.open('w') as file:
            result = subprocess.run([str(arg) for arg in command], cwd=ROOT,
                                    stdout=file, stderr=subprocess.STDOUT)
        if result.returncode:
            print('\n'.join(log.read_text(errors='replace').splitlines()[-80:]))
            raise SystemExit(result.returncode)

    configure = ['cmake', '-S', ROOT / 'Core', '-B', build, '-DMXLOGGER_BUILD_TESTS=ON']
    configure += ['-A', 'x64'] if os.name == 'nt' else [f'-DCMAKE_BUILD_TYPE={args.configuration}']
    run('configure', configure)
    write_report(build / 'local-core.json', [check_cmake(build / 'CMakeCache.txt')])
    run('build', ['cmake', '--build', build, '--config', args.configuration, '--parallel', '4'])
    run('tests', ['ctest', '--test-dir', build, '-C', args.configuration,
                 '--output-on-failure', '--no-tests=error', '--output-junit', build / 'test-results.xml'])
    print(f'PASS: Core {args.configuration}; logs: {build}')


if __name__ == '__main__':
    main()
