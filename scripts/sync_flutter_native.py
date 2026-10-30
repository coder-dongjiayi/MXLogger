#!/usr/bin/env python3
"""Synchronize Apple bridge ABI headers from Core; Windows ships a binary DLL."""
import argparse
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parent.parent
PLUGIN = ROOT / 'platform/flutter_mxlogger'


def sources():
    result = {}
    apple = PLUGIN / 'darwin/flutter_mxlogger/Sources/flutter_mxlogger'
    result[apple / 'include/flutter_mxlogger/mxlogger_ffi.h'] = ROOT / 'Core/ffi/mxlogger_ffi.h'
    result[apple / 'mxlogger_ffi_memory.hpp'] = ROOT / 'Core/ffi/mxlogger_ffi_memory.hpp'
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    expected = sources()
    missing = [p for p, source in expected.items() if not p.exists() or p.read_bytes() != source.read_bytes()]
    if args.check:
        if missing:
            raise SystemExit('Run python3 scripts/sync_flutter_native.py; mismatched files:\n' +
                             '\n'.join(str(p.relative_to(ROOT)) for p in missing))
    else:
        for p in missing:
            p.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(expected[p], p)
    print(f'PASS: {len(expected)} generated Flutter native files match checkout Core')


if __name__ == '__main__':
    main()
