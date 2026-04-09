CodeComplexity.jl Release Notes
============================

Main
-------

- **New:** PLR0913-style checks for “too many arguments”: `argument_count_report`, `file_argument_counts`, `directory_argument_counts`, `package_argument_counts`, `check_argument_count` (default `max_args=5`, matching Ruff’s `lint.pylint.max-args`), with types `FunctionArguments` and `FileArguments`.
