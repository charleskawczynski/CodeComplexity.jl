CodeComplexity.jl Release Notes
============================

Main
-------

- **Breaking / metric-neutral API:** The public verbs no longer carry a "complexity" suffix, since the package now hosts metrics that are not strictly complexity (e.g. `ArgumentCountComplexity`, user-defined `LineCount`, …). Rename map: `metric_complexity` → `measure`, `complexity_report` → `measure_report`, `file_complexity` → `file_measure`, `directory_complexity` → `directory_measure`, `package_complexity` → `package_measure`, `check_complexity` → `check_measure`, `FunctionComplexity` → `FunctionMeasure`, `FileComplexity` → `FileMeasure`. Field names (`value`, `total_value`, `name`, `line`, `path`, `functions`) and the metric singletons (`CyclomaticComplexity`, `CognitiveComplexity`, `ArgumentCountComplexity`, `AbstractMetric`) are unchanged. Traits `metric_label` and `default_max_value` are unchanged.
- **Breaking / no exports:** The package now exports nothing. Users must qualify every reference, e.g. `import CodeComplexity as CC; CC.measure(CC.CyclomaticComplexity(), code)`. This shrinks the surface area, prevents collisions with very generic names like `measure` / `check`, and makes future additions impossible to confuse with built-in identifiers.
- **Restructure:** `src/api.jl` is now implementation-free — it contains only the abstract type, metric singletons, parametric result types, and `function … end` stubs with docstrings. Shared infrastructure (AST extraction, file / directory / package walks, threshold checking, default trait fallbacks, `Base.show`) lives in the new `src/common.jl`. Each per-metric file (`cyclomatic_complexity.jl`, `cognitive_complexity.jl`, `argument_counts.jl`) only adds its own `measure(::M, …)` method plus any error-message overrides.
- **Deprecations:** Two layers of deprecation shims, both in `src/deprecated.jl`:
  - **v2 (`*_complexity` verbs):** `metric_complexity`, `complexity_report`, `file_complexity`, `directory_complexity`, `package_complexity`, `check_complexity` forward (with `Base.depwarn`) to the new `measure`-suffixed names. The const aliases `FunctionComplexity` / `FileComplexity` continue to refer to the parametric types.
  - **v1 (pre-singleton):** `cyclomatic_complexity`, `cognitive_complexity[_report]`, `argument_count_report`, `file_*`, `directory_*`, `package_*`, `check_*`, plus the type aliases `FunctionCognitiveComplexity`, `FileCognitiveComplexity`, `FunctionArguments`, `FileArguments` continue to work as before. Old field names (`.complexity`, `.arg_count`, `.total_complexity`, `.total_arguments`) still read transparently from `.value` / `.total_value`.
  All deprecated names live under the same `CC.` namespace as the v3 API.

Earlier work
-------

- **(prior main):** All three metrics (cyclomatic, cognitive, argument count) shared a single dispatched API under the `*_complexity` verb names (now deprecated; see above). Singletons `CyclomaticComplexity()`, `CognitiveComplexity()`, `ArgumentCountComplexity()` (`<: AbstractMetric`) drove every entry point. Result types `FunctionComplexity{M}` (with field `value`) and `FileComplexity{M}` (with field `total_value`). Traits `metric_label` and `default_max_value` (10 / 15 / 5).
- `metric_complexity(::ArgumentCountComplexity, expr)` operates on a function signature / definition, addressing the missing `argument_count` entry point in the previous design.
- Custom metrics can be added by defining a singleton `<: AbstractMetric` plus a single `measure(::M, expr)` method; the entire reporting / file-walking / threshold-checking pipeline is then available for free.

v0.x
-------

- **New:** Cognitive complexity (G. Ann Campbell / SonarSource, 2023): `cognitive_complexity`, `cognitive_complexity_report`, `file_cognitive_complexity`, `directory_cognitive_complexity`, `package_cognitive_complexity`, `check_cognitive_complexity` (default `max_complexity=15`, matching Sonar's recommendation), with types `FunctionCognitiveComplexity` and `FileCognitiveComplexity`. Counts nested control flow, `&&`/`||` sequences, `catch`, `@goto`, and direct recursion; lambdas and nested function definitions raise the nesting level without adding their own increment.
- **New:** PLR0913-style checks for "too many arguments": `argument_count_report`, `file_argument_counts`, `directory_argument_counts`, `package_argument_counts`, `check_argument_count` (default `max_args=5`, matching Ruff's `lint.pylint.max-args`), with types `FunctionArguments` and `FileArguments`.
- **New:** `ignore` on those APIs: skip definitions by symbol/string (including `"@macro"`), or by function/type/builtin via `nameof`. See README and the `argument_count_report` docstring for caveats (unqualified names, macros, complex types, lambdas).
