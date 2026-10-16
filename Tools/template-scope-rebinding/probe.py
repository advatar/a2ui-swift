#!/usr/bin/env python3
"""Execute exact production reuse methods with real ComponentNode/UIState types.

NOT a renderer build: RawComponent/ComponentType/accessibility are minimal carrier
fixtures; message decoding, DataContext, SwiftUI diffing and button dispatch are
not exercised. No method under test is reimplemented. A separate native suite
must run on a Mac before dependency promotion.
"""
from __future__ import annotations
import argparse
import hashlib
from pathlib import Path
import re
import subprocess


def git_blob(data: bytes) -> str:
    return hashlib.sha1(f"blob {len(data)}\0".encode() + data).hexdigest()


def extract(source: str, marker: str) -> str:
    start = source.index(marker)
    opening = source.index("{", start)
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start:index + 1]
    raise ValueError(f"Unterminated production section: {marker}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--expected-source-blob", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--static-stdlib", action="store_true", help="Use the installed static Swift runtime; no source changes")
    parser.add_argument("--expect", choices=("regression", "pass"), required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    source_path = args.root / "Sources/A2UISwiftUI/SurfaceViewModel.swift"
    source_bytes = source_path.read_bytes()
    if git_blob(source_bytes) != args.expected_source_blob:
        raise SystemExit("REFUSED: SurfaceViewModel source identity differs")
    dependencies = {
        "Sources/A2UISwiftCore/Rendering/ComponentNode.swift": "5d249f9584184dad0b1d4505c466fce47d6d64f7",
        "Sources/A2UISwiftCore/State/UIState.swift": "621b4db434eedf4435977da200aad0ada8f02ccd",
    }
    for path, expected in dependencies.items():
        data = (args.root / path).read_bytes()
        if git_blob(data) != expected:
            raise SystemExit(f"REFUSED: production dependency identity differs: {path}")
        (args.output / Path(path).name).write_bytes(data)
    source = source_bytes.decode("utf-8")
    methods = [extract(source, "    private func " + name + "(") for name in (
        "templateSuffix", "reconcileNode", "reconcileChildren", "collectUIStates", "migrateUIStates"
    )]
    key_type = extract(source, "    private struct UIStateKey:") if "    private struct UIStateKey:" in source else ""
    map_type = re.search(r"var oldStateMap: (\[[^\n]+\]) = \[:\]", source)
    if map_type is None:
        raise SystemExit("REFUSED: production state-map declaration not found")
    wrapper = f"""
final class ExtractedReconciler {{
{key_type}
{chr(10).join(methods)}
    func rebuild(_ existing: ComponentNode, _ incoming: ComponentNode) -> ComponentNode {{
        var oldStateMap: {map_type.group(1)} = [:]
        collectUIStates(from: existing, into: &oldStateMap)
        migrateUIStates(node: incoming, from: oldStateMap)
        return reconcileNode(existing: existing, new: incoming) ? existing : incoming
    }}
    func migrateOnly(_ existing: ComponentNode, _ incoming: ComponentNode) {{
        var oldStateMap: {map_type.group(1)} = [:]
        collectUIStates(from: existing, into: &oldStateMap)
        migrateUIStates(node: incoming, from: oldStateMap)
    }}
    func suffix(_ path: String = "/", _ index: Int = 0) -> String {{
        templateSuffix(dataContextPath: path, index: index)
    }}
}}
"""
    (args.output / "ExtractedReconciler.swift").write_text(wrapper)
    support = Path(__file__).with_name("Probe.swift").read_bytes()
    (args.output / "Probe.swift").write_bytes(support)
    print(f"Source blob: {git_blob(source_bytes)}", flush=True)
    print(subprocess.check_output(["swift", "--version"], text=True).strip(), flush=True)
    source_files = [str(args.output / p) for p in (
        "ComponentNode.swift", "UIState.swift", "ExtractedReconciler.swift", "Probe.swift"
    )]
    for optimization in ("-Onone", "-O"):
        executable = args.output / ("probe-debug" if optimization == "-Onone" else "probe-release")
        subprocess.run(["swiftc", *(["-static-stdlib"] if args.static_stdlib else []),
                        "-package-name", "TemplateScopeProbe", optimization,
                        *source_files, "-o", str(executable)], check=True)
        result = subprocess.run([str(executable)], capture_output=True, text=True)
        (args.output / f"{executable.name}.log").write_text(result.stdout + result.stderr)
        print(optimization + "\n" + result.stdout, flush=True)
        failures = {line.split()[1] for line in result.stdout.splitlines() if line.startswith("FAIL ")}
        expected_failures = {
            "array_scope", "migration_scope", "round_trip", "dictionary_scope",
            "nested_scope", "parallel_scope_migration",
        } if args.expect == "regression" else set()
        if failures != expected_failures or result.returncode != (1 if expected_failures else 0):
            raise SystemExit(f"UNEXPECTED outcome: failures={sorted(failures)}, exit={result.returncode}")
    print(f"EXPECTED {args.expect} outcome verified at both optimization levels; NOT Apple qualification.")


if __name__ == "__main__":
    main()
