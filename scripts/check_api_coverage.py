#!/usr/bin/env python3
"""Check published API entries against execution data, not source-name searches.

Core/Apple use LLVM function counters, Java uses JaCoCo method counters, and
Dart uses the first executable LCOV line of each public method/getter. Three
compiler-synthesized ObjC accessors are checked by explicit passing XCTest
assertions because Clang does not emit their coverage mappings.
"""
import argparse
import html
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent


def source(path):
    text = (ROOT / path).read_text()
    return re.sub(r"/\*.*?\*/|//[^\n]*", "", text, flags=re.S)


def arity(arguments):
    if not arguments.strip() or arguments.strip() == "void":
        return 0
    depth = 0
    count = 1
    for char in arguments:
        if char in "<([":
            depth += 1
        elif char in ">)]":
            depth -= 1
        elif char == "," and depth == 0:
            count += 1
    return count


def llvm(path):
    return json.loads(Path(path).read_text())["data"][0]


def core_entries(data):
    expected = {}
    for path, cls in [("Core/mxlogger.hpp", "mxlogger::mxlogger"),
                      ("Core/mxlogger_util.hpp", "mxlogger::util::mxlogger_util")]:
        declarations = source(path).split("public:", 1)[1]
        for statement in declarations.split(";"):
            match = re.search(r"(\w+)\s*\(([^;]*)\)\s*(?:const)?\s*(?:noexcept)?\s*$", statement)
            if match:
                key = f"{cls}::{match[1]}/{arity(match[2])}"
                if key in expected:
                    raise ValueError(f"Ambiguous overload {key}: extend the checker with parameter types")
                expected[key] = 0
    functions = data["functions"]
    names = subprocess.check_output(["c++filt"], input="\n".join(f["name"] for f in functions), text=True).splitlines()
    for name, function in zip(names, functions):
        match = re.match(r"(mxlogger::(?:mxlogger|util::mxlogger_util)::\w+)\((.*)\)(?: const)?$", name)
        if match:
            key = f"{match[1]}/{arity(match[2])}"
            if key in expected:
                expected[key] += function["count"]
    return [{"api": key, "count": count, "tested": count > 0, "evidence": "LLVM function counter"}
            for key, count in sorted(expected.items())]


def apple_entries(data, log):
    expected = set()
    for line in source("platform/iOS/MXLogger/MXLogger/include/MXLogger/MXLogger.h").splitlines():
        line = line.strip()
        if re.match(r"^[+-]\s*\(", line):
            sign = line[0]
            decl = re.sub(r"^[+-]\s*\([^)]*\)\s*", "", line)
            decl = decl.split("NS_SWIFT_NAME")[0].split("DEPRECATED_MSG_ATTRIBUTE")[0]
            pieces = re.findall(r"(\w+)\s*:", decl)
            selector = "".join(piece + ":" for piece in pieces) if pieces else re.match(r"\w+", decl)[0]
            expected.add(f"{sign}[MXLogger {selector}]")
        elif line.startswith("@property"):
            match = re.match(r"@property\s*\(([^)]*)\)(.*)", line)
            decl = match[2].split("NS_SWIFT_NAME")[0].split("DEPRECATED_MSG_ATTRIBUTE")[0].rstrip("; ")
            name = re.search(r"(\w+)$", decl)[1]
            expected.add(f"-[MXLogger {name}]")
            if "readonly" not in match[1]:
                expected.add(f"-[MXLogger set{name[0].upper() + name[1:]}:]")
    counts = {}
    for function in data["functions"]:
        match = re.search(r"[+-]\[MXLogger [^\]]+\]", function["name"])
        if match:
            counts[match[0]] = counts.get(match[0], 0) + function["count"]
    synthesized = {
        "-[MXLogger loggerToken]": "testLoggerTokenIs32CharMd5AndStable",
        "-[MXLogger shouldRemoveExpiredDataWhenEnterBackground]": "testPropertyGettersAndConfigurationAffectWrites",
        "-[MXLogger setShouldRemoveExpiredDataWhenEnterBackground:]": "testPropertyGettersAndConfigurationAffectWrites",
    }
    passed = set(re.findall(r"Test Case '-\[MXLoggerTests (\w+)\]' passed", Path(log).read_text()))
    entries = []
    for api in sorted(expected):
        if api in counts:
            entries.append({"api": api, "count": counts[api], "tested": counts[api] > 0, "evidence": "LLVM function counter"})
        else:
            test = synthesized.get(api)
            entries.append({"api": api, "count": None, "tested": test in passed,
                            "evidence": f"synthesized accessor: passing XCTest {test}" if test else "no coverage mapping"})
    return entries


def descriptor_arity(descriptor):
    arguments = descriptor[1:descriptor.index(")")]
    index = count = 0
    while index < len(arguments):
        while arguments[index] == "[":
            index += 1
        index = arguments.index(";", index) + 1 if arguments[index] == "L" else index + 1
        count += 1
    return count


def java_entries(path):
    expected = {}
    text = re.sub(r"@\w+(?:\([^)]*\))?", "", source("platform/Android/MXLogger/mxlogger/src/main/java/com/dongjiayi/mxlogger/MXLogger.java"))
    pattern = r"\bpublic\s+(?:(?:static|final|synchronized)\s+)*(?:[\w<>?,\[\].]+\s+)?(\w+)\s*\(([^)]*)\)"
    for match in re.finditer(pattern, text):
        key = f"MXLogger.{match[1]}/{arity(match[2])}"
        if key in expected:
            raise ValueError(f"Ambiguous overload {key}: extend the checker with parameter types")
        expected[key] = 0
    document = ET.parse(path)
    for cls in document.findall(".//class"):
        if cls.get("name") != "com/dongjiayi/mxlogger/MXLogger":
            continue
        for method in cls.findall("method"):
            name = "MXLogger" if method.get("name") == "<init>" else method.get("name")
            key = f"MXLogger.{name}/{descriptor_arity(method.get('desc'))}"
            if key in expected:
                count = method.find("counter[@type='METHOD']")
                expected[key] = int(count.get("covered")) if count is not None else 0
    return [{"api": api, "count": count, "tested": count > 0, "evidence": "JaCoCo method counter"}
            for api, count in sorted(expected.items())]


def dart_entries(path):
    suffix = "lib/src/flutter_mxlogger.dart"
    hits = {}
    for section in Path(path).read_text().split("end_of_record"):
        if not any(row.startswith("SF:") and row.endswith(suffix) for row in section.splitlines()):
            continue
        for row in section.splitlines():
            if row.startswith("DA:"):
                line, count = row[3:].split(",")[:2]
                hits[int(line)] = int(count)
    lines = (ROOT / "platform/flutter_mxlogger" / suffix).read_text().splitlines()
    entries = []
    for start, line in enumerate(lines):
        cls = re.match(r"^(?:class|extension) (\w+)", line)
        if not cls:
            continue
        end = next(index for index in range(start + 1, len(lines)) if lines[index] == "}")
        declarations = []
        for index in range(start + 1, end):
            current = lines[index]
            if not re.match(r"^  \S", current):
                continue
            getter = re.match(r"^  (?:static )?[^=;]+?\b(get|set)\s+(\w+)", current)
            method = re.match(r"^  (?:static |factory )?(?:[\w<>,?.\[\] \t]+\s+)?(\w+)\s*\(", current)
            if getter:
                declarations.append((index + 1, getter[2], getter[1] + ":"))
            elif method:
                declarations.append((index + 1, method[1], ""))
        for offset, (begin, name, kind) in enumerate(declarations):
            if name.startswith("_"):
                continue
            stop = declarations[offset + 1][0] if offset + 1 < len(declarations) else end + 1
            executable = sorted(n for n in hits if begin <= n < stop)
            first = executable[0] if executable else None
            count = hits.get(first, 0)
            entries.append({"api": f"{cls[1]}.{kind}{name}", "line": first, "count": count,
                            "tested": count > 0, "evidence": "LCOV first executable line"})
    return entries


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core-json", required=True)
    parser.add_argument("--apple-json", required=True)
    parser.add_argument("--apple-log", required=True)
    parser.add_argument("--java-xml", required=True)
    parser.add_argument("--dart-lcov", required=True)
    parser.add_argument("--output", required=True)
    options = parser.parse_args()
    layers = {
        "C++ published headers": core_entries(llvm(options.core_json)),
        "Apple Objective-C/Swift API": apple_entries(llvm(options.apple_json), options.apple_log),
        "Android Java API (real host JNI/Core)": java_entries(options.java_xml),
        "Flutter native Dart API": dart_entries(options.dart_lcov),
    }
    result = {"scope": "Public API entry execution/assertions, not 100% line/branch or every OS failure path.", "layers": {}}
    result["passed"] = True
    for name, entries in layers.items():
        assert entries, f"No APIs discovered for {name}"
        tested = sum(entry["tested"] for entry in entries)
        result["layers"][name] = {"total": len(entries), "tested": tested,
                                  "percent": round(100 * tested / len(entries), 2), "entries": entries}
        result["passed"] &= tested == len(entries)
        print(f"{name}: {tested}/{len(entries)}")
        for entry in entries:
            if not entry["tested"]:
                print(f"  MISSING {entry['api']}")
    output = Path(options.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    rows = []
    for name, layer in result["layers"].items():
        rows.append(f"<h2>{html.escape(name)}: {layer['tested']}/{layer['total']}</h2><table><tr><th>API</th><th>Tested</th><th>Evidence</th></tr>")
        for entry in layer["entries"]:
            rows.append(f"<tr><td>{html.escape(entry['api'])}</td><td>{entry['tested']}</td><td>{html.escape(entry['evidence'])}</td></tr>")
        rows.append("</table>")
    output.with_suffix(".html").write_text("<!doctype html><meta charset='utf-8'><title>MXLogger API coverage</title>"
        "<style>body{font:15px system-ui;max-width:1100px;margin:40px auto}table{border-collapse:collapse;width:100%}"
        "td,th{text-align:left;border:1px solid #ccc;padding:7px}h2{margin-top:32px}</style>"
        "<h1>MXLogger API coverage</h1><p>" + html.escape(result["scope"]) + "</p>" + "".join(rows))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
