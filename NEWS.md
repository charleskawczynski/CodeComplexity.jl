CodeComplexity.jl Release Notes
============================

Main
-------

- **New:** Cognitive complexity (G. Ann Campbell / SonarSource, 2023): `cognitive_complexity`, `cognitive_complexity_report`, `file_cognitive_complexity`, `directory_cognitive_complexity`, `package_cognitive_complexity`, `check_cognitive_complexity` (default `max_complexity=15`, matching Sonar's recommendation), with types `FunctionCognitiveComplexity` and `FileCognitiveComplexity`. Counts nested control flow, `&&`/`||` sequences, `catch`, `@goto`, and direct recursion; lambdas and nested function definitions raise the nesting level without adding their own increment.
- **New:** PLR0913-style checks for “too many arguments”: `argument_count_report`, `file_argument_counts`, `directory_argument_counts`, `package_argument_counts`, `check_argument_count` (default `max_args=5`, matching Ruff’s `lint.pylint.max-args`), with types `FunctionArguments` and `FileArguments`.
- **New:** `ignore` on those APIs: skip definitions by symbol/string (including `"@macro"`), or by function/type/builtin via `nameof`. See README and the `argument_count_report` docstring for caveats (unqualified names, macros, complex types, lambdas).
