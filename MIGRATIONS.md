# Migrations

`CodeComplexity.jl` keeps two earlier API surfaces alive as deprecation
shims so existing `using CodeComplexity` code keeps working. The shims
forward into the current `measure_*` / `check_measure` API and emit a
`Base.depwarn` notice that points at the new name.

This document is the migration reference; the canonical, current API is
documented in [README.md](README.md).

## Layers of deprecation

- **v1 (pre-singleton):** `cyclomatic_complexity`, `argument_count_report`,
  `file_argument_counts`, `directory_argument_counts`,
  `package_argument_counts`, `check_argument_count`, `FunctionArguments`,
  `FileArguments`, …
- **v2 (renamed-but-still-`*_complexity`):** `metric_complexity`,
  `complexity_report`, `file_complexity`, `directory_complexity`,
  `package_complexity`, `check_complexity`, `FunctionComplexity`,
  `FileComplexity`.

`CognitiveComplexity` ships for the first time alongside the
metric-neutral verbs, so it has no v1 shims — use the new API directly
(`measure_code(CognitiveComplexity(), …)`,
`measure_report(CognitiveComplexity(), …)`, etc.).

## Migration map

Representative entries; everything in the older surfaces forwards
through the same way:

| Old | New |
|-----|-----|
| `metric_complexity(metric, x)` | `measure_code(metric, x)` |
| `complexity_report(metric, code; max_value=N)` | `measure_report(metric, code; max_value=N)` |
| `file_complexity(metric, p; max_value=N)` | `measure_file(metric, p; max_value=N)` |
| `directory_complexity(metric, d; …)` | `measure_directory(metric, d; …)` |
| `package_complexity(metric, p; …)` | `measure_package(metric, p; …)` |
| `check_complexity(metric, t; …)` | `check_measure(metric, t; …)` |
| `FunctionComplexity{M}` / `FileComplexity{M}` | `FunctionMeasure{M}` / `FileMeasure{M}` |
| `cyclomatic_complexity(x)` | `measure_code(CyclomaticComplexity(), x)` |
| `argument_count_report(code; max_args=N, ignore=…)` | `measure_report(ArgumentCountComplexity(), code; max_value=N, ignore=…)` |
| `file_argument_counts` | `measure_file(ArgumentCountComplexity(), p; …)` |
| `check_argument_count` | `check_measure(ArgumentCountComplexity(), …)` |
| `FunctionArguments`, `FileArguments` | `FunctionMeasure{ArgumentCountComplexity}`, `FileMeasure{ArgumentCountComplexity}` |

## Field-name compatibility

The old field names (`.complexity`, `.arg_count`, `.total_complexity`,
`.total_arguments`) on the parametric result types are forwarded
transparently to `.value` / `.total_value` for source compatibility, so
e.g. `fc.complexity` continues to work on a
`FunctionMeasure{CyclomaticComplexity}`.

All deprecated names are re-exported from `src/deprecated.jl`, so
existing `using CodeComplexity` code keeps working without
modification.
