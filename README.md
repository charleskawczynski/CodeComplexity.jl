# CodeComplexity.jl

[![CI](https://github.com/charleskawczynski/CodeComplexity.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/charleskawczynski/CodeComplexity.jl/actions/workflows/ci.yml)

Measure **cyclomatic complexity** of Julia code. Use it to find overly complex functions, enforce limits in tests or CI, and scan files, directories, or whole packages.

## Installation

```julia
using Pkg
Pkg.add("CodeComplexity")
```

## Quick start

```julia
using CodeComplexity

# Single expression or code string
cyclomatic_complexity("""
function foo(x)
    if x > 0
        return x
    else
        return -x
    end
end
""")  # 2

# Per-function report from a string
complexity_report(read("src/MyModule.jl", String))

# Analyze a file
fc = file_complexity("src/MyModule.jl")
println("Total: ", fc.total_complexity)
for f in fc.functions
    println("  ", f.name, ": ", f.complexity, " (line ", f.line, ")")
end

# Analyze a directory (recursive)
directory_complexity("src/")

# Analyze a package (by name or module)
package_complexity("CodeComplexity")
using MyPackage; package_complexity(MyPackage)

# Enforce a limit (e.g. in tests or CI)
check_complexity(MyPackage; max_complexity=10)  # throws if any function exceeds 10
violations = check_complexity("src/"; max_complexity=10, throw_on_violation=false)
```

## Too many arguments (Ruff PLR0913–style)

You can flag definitions whose **signatures** have more than a chosen number of parameters (positional slots plus keyword slots), in the spirit of Ruff’s [PLR0913](https://docs.astral.sh/ruff/rules/too-many-arguments/) / Pylint’s `max-args` (Ruff’s default is **5**).

```julia
argument_count_report(read("src/MyModule.jl", String))
argument_count_report(code; max_args=5)   # only definitions with arg_count > 5

file_argument_counts("src/MyModule.jl"; max_args=5)
directory_argument_counts("src/"; max_args=5)
package_argument_counts(CodeComplexity; max_args=5)

check_argument_count("src/"; max_args=5)  # throws if any definition exceeds the limit
```

Types: **`FunctionArguments`** (`name`, `arg_count`, `line`) and **`FileArguments`** (`path`, `functions`, `total_arguments`).

### Ignoring definitions (`ignore`)

All argument-count entry points accept optional **`ignore`**: an iterable of names or values that resolve to a name (see below). Ignored definitions are dropped **before** the `max_args` filter.

```julia
# Symbols / strings (macros use the "@name" form, e.g. "@generated")
check_argument_count(MyPackage; max_args=5, ignore=(:legacy_api, "@my_macro"))

# Functions, types / constructors, builtins — matched via nameof → same unqualified name as in source
check_argument_count(MyPackage; max_args=5, ignore=(wide_options, MyStruct))
```

**Caveats**

- Matching is by **unqualified name** only: every definition with that name is skipped, even across modules.
- **Macros** usually have no convenient callable to pass; use `Symbol` or `String` with the stored form **`"@macroname"`**.
- **Complex type objects** (e.g. `Union{Int,Nothing}`) use `nameof`; that string may not match a simple identifier in source—prefer symbols or strings when unsure.
- **`->` lambdas** are reported as **`"<anonymous>"`** if you need to ignore them.

## What is cyclomatic complexity?

Cyclomatic complexity counts **decision points** in the control flow (plus one). Higher values mean more branches and usually harder-to-test or harder-to-follow code.

The metric counts:

- `if` / `elseif`
- `for` / `while`
- `try` / `catch`
- Short-circuit `&&` / `||`
- Ternary `? :`
- `@goto`

Minimum complexity is 1 (no branches). A single `if` gives 2; each extra branch adds one.

## Main API

| Function | Description |
|----------|-------------|
| `cyclomatic_complexity(expr)` / `cyclomatic_complexity(code::String)` | Complexity of one expression or code string |
| `complexity_report(code; max_complexity=nothing)` | Per-function complexity for code string; optional threshold filter |
| `file_complexity(path; max_complexity=nothing)` | Per-function complexity for a file |
| `directory_complexity(dir; recursive=true, max_complexity=nothing)` | All `.jl` files in a directory |
| `package_complexity(pkg_or_name; max_complexity=nothing)` | All source files of a package (module or name) |
| `check_complexity(path_or_pkg; max_complexity=10, throw_on_violation=true)` | Assert no function exceeds the limit; useful in tests/CI |
| `argument_count_report(code; max_args=nothing, ignore=nothing)` | Parameter count per definition; optional `max_args` filter (`arg_count > max_args`); optional `ignore` |
| `file_argument_counts(path; max_args=nothing, ignore=nothing)` | Same as above for one file |
| `directory_argument_counts(dir; recursive=true, max_args=nothing, ignore=nothing)` | All `.jl` files in a directory |
| `package_argument_counts(pkg_or_name; max_args=nothing, ignore=nothing)` | All package sources |
| `check_argument_count(path_or_pkg; max_args=5, throw_on_violation=true, ignore=nothing)` | Assert no definition exceeds the parameter limit (default 5, like Ruff) |

Types:

- **`FunctionComplexity`**: `name`, `complexity`, `line`
- **`FileComplexity`**: `path`, `functions`, `total_complexity`
- **`FunctionArguments`**: `name`, `arg_count`, `line`
- **`FileArguments`**: `path`, `functions`, `total_arguments`

## Use in tests and CI

To fail tests when any function exceeds a complexity threshold:

```julia
using Test, CodeComplexity, MyPackage

@testset "Complexity" begin
    check_complexity(MyPackage; max_complexity=10)
end
```

Or scan a directory in a script:

```julia
check_complexity("src/"; max_complexity=15)
```

## Code style (JuliaFormatter)

Formatting is enforced by [JuliaFormatter.jl](https://github.com/domluna/JuliaFormatter.jl) via the [JuliaFormatter](.github/workflows/JuliaFormatter.yml) workflow. Local rules live in [`.JuliaFormatter.toml`](.JuliaFormatter.toml) (style, indent, margin, ignore). To format the repo:

```bash
julia -e 'using JuliaFormatter; JuliaFormatter.format(".")'
```

Or from a Julia REPL: `using JuliaFormatter; JuliaFormatter.format(".")`.

## Aqua.jl

This package uses **[Aqua.jl](https://github.com/JuliaTesting/Aqua.jl)** in its test suite (`Aqua.test_all(CodeComplexity)`) for general package-quality checks.

**Relevance for Aqua:** The `check_complexity` feature could fit as an optional Aqua test (e.g. `test_cyclomatic_complexity`): a single, automatable check that fails when any function exceeds a complexity threshold, consistent with Aqua's other checks (ambiguities, undefined exports, stale deps, etc.). That would let users opt in via something like `Aqua.test_all(MyPackage; cyclomatic_complexity=(max=10,))` without adding a separate test. Until or unless that is added to Aqua, you can run both in the same test suite—Aqua for project hygiene and CodeComplexity for complexity limits.

## License

See [LICENSE](LICENSE).
