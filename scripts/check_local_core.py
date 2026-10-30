#!/usr/bin/env python3
"""Fail if resolved MXLogger sources are not from the checkout being tested."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def core_version():
    return re.search(r'#define MXLOGGER_CORE_VERSION "([^"]+)"',
                     (ROOT / 'Core/mxlogger_version.hpp').read_text())[1]


def check_cmake(cache):
    cache = Path(cache)
    match = re.search(r'^MXLoggerCore_SOURCE_DIR:[^=]+=(.+)$', cache.read_text(), re.M)
    if not match or Path(match[1].strip()).resolve() != (ROOT / 'Core').resolve():
        raise RuntimeError(f'CMake does not resolve this checkout Core: {cache}')
    return {'kind': 'cmake', 'cache': str(cache.resolve()), 'core': match[1].strip()}


def check_pods(lock):
    lock = Path(lock)
    data = json.loads(subprocess.check_output(
        ['ruby', '-ryaml', '-rjson', '-e', 'puts JSON.generate(YAML.load_file(ARGV[0]))', str(lock)], text=True))
    sources = data.get('EXTERNAL SOURCES', {})
    for name in ['MXLogger', 'MXLoggerCore']:
        settings = sources.get(name, {})
        path = settings.get('path', settings.get(':path'))
        if not path or (lock.parent / path).resolve() != ROOT:
            raise RuntimeError(f'{name} must resolve to this checkout, got {sources.get(name)} in {lock}')
    return {'kind': 'cocoapods', 'lock': str(lock.resolve()), 'sources': sources}


def check_spm(mirror):
    mirror = Path(mirror)
    # Compare every runtime source/header, not just a shared version string.
    paths = [p for p in (ROOT / 'Core').rglob('*')
             if p.suffix in {'.h', '.hpp', '.c', '.cpp', '.S'}
             and 'tests' not in p.relative_to(ROOT / 'Core').parts
             and 'ffi' not in p.relative_to(ROOT / 'Core').parts
             and 'MXLoggerCore.xcodeproj' not in p.relative_to(ROOT / 'Core').parts]
    for original in paths:
        copied = mirror / 'Sources/MXLoggerCore' / original.relative_to(ROOT / 'Core')
        if not copied.exists() or original.read_bytes() != copied.read_bytes():
            raise RuntimeError(f'SwiftPM Core source mismatch: {copied}')
    return {'kind': 'swiftpm-local-mirror', 'path': str(mirror.resolve()), 'verified_files': len(paths)}


def check_xcode(project):
    project = Path(project)
    data = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-',
                                              str(project / 'project.pbxproj')], text=True))
    references = [item for item in data['objects'].values()
                  if item.get('isa') == 'PBXFileReference'
                  and item.get('path', '').endswith('MXLoggerCore.xcodeproj')]
    expected = ROOT / 'Core/MXLoggerCore.xcodeproj'
    if len(references) != 1 or (project.parent / references[0]['path']).resolve() != expected:
        raise RuntimeError(f'Apple project must reference this checkout Core: {references}')
    return {'kind': 'xcode-project', 'project': str(project.resolve()), 'core_project': str(expected)}


def write_report(output, evidence):
    report = {'checkout': str(ROOT), 'core': str(ROOT / 'Core'), 'version': core_version(),
              'mxlogger_cpp_sha256': hashlib.sha256((ROOT / 'Core/mxlogger.cpp').read_bytes()).hexdigest(),
              'evidence': evidence}
    Path(output).parent.mkdir(parents=True, exist_ok=True)
    Path(output).write_text(json.dumps(report, indent=2) + '\n')
    print(f'PASS: checkout Core {report["version"]}; provenance: {output}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cmake-cache', action='append', default=[])
    parser.add_argument('--pod-lock', action='append', default=[])
    parser.add_argument('--spm-mirror', action='append', default=[])
    parser.add_argument('--xcode-project', action='append', default=[])
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    evidence = ([check_cmake(p) for p in args.cmake_cache] +
                [check_pods(p) for p in args.pod_lock] +
                [check_spm(p) for p in args.spm_mirror] +
                [check_xcode(p) for p in args.xcode_project])
    if not evidence:
        parser.error('Provide at least one resolved dependency to verify')
    write_report(args.output, evidence)


if __name__ == '__main__':
    main()
