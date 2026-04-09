CodeComplexity.jl Release Notes
============================

Main
-------

- **New:** PLR0913-style checks for “too many arguments”: `argument_count_report`, `file_argument_counts`, `directory_argument_counts`, `package_argument_counts`, `check_argument_count` (default `max_args=5`, matching Ruff’s `lint.pylint.max-args`), with types `FunctionArguments` and `FileArguments`.
- **New:** `ignore` on those APIs: skip definitions by symbol/string (including `"@macro"`), or by function/type/builtin via `nameof`. See README and the `argument_count_report` docstring for caveats (unqualified names, macros, complex types, lambdas).
