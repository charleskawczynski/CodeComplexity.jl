# CodeComplexity.jl

[![CI](https://github.com/charleskawczynski/CodeComplexity.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/charleskawczynski/CodeComplexity.jl/actions/workflows/ci.yml)

Measure code-quality metrics on Julia source through a single dispatched
API. Built-in metrics include:

- **Cyclomatic complexity** (McCabe)
- **Cognitive complexity** (Campbell / SonarSource)
- **Argument count** (Ruff `PLR0913`-style)

Use CodeComplexity.jl to find overly complex or oversized definitions,
enforce limits in tests or CI, and scan files, directories, or whole
packages.

## Installation

```julia
using Pkg
Pkg.add("CodeComplexity")
```

## One API, every metric

Every entry point dispatches on a metric singleton. The metric types,
result types, and the verbs are all exported, so the simplest entry
is `using CodeComplexity`:

```julia
using CodeComplexity
```

All public verbs share a `measure_*` prefix. The threshold-checking
verb's canonical name is `check_measure` (its semantics differ from the
rest of the family — it asserts and throws rather than returning data),
but it's also available as `measure_check`, an exact `const` alias, so
that `measure_<TAB>` at the REPL reveals the entire family at once.

| Singleton | What it measures | Default threshold |
|-----------|------------------|-------------------|
| `CyclomaticComplexity()` | McCabe decision points + 1 | 10 |
| `CognitiveComplexity()` | Sonar / Campbell cognitive complexity | 15 |
| `ArgumentCountComplexity()` | Parameter count of a definition (Ruff PLR0913) | 5 |

All metrics plug into the same six verbs:

```julia
measure_code(metric, expr_or_code)               # one expression
measure_report(metric, code; max_value=...)      # per-definition vector
measure_file(metric, path; max_value=...)        # one file
measure_directory(metric, dir; recursive=true, max_value=...)
measure_package(metric, pkg_or_name; max_value=...)
measure_check(metric, path_or_pkg; max_value=..., throw_on_violation=true) # exact alias of `check_measure`
check_measure(metric, path_or_pkg; max_value=..., throw_on_violation=true)
```

## Quick start

```julia
using CodeComplexity

code = """
function foo(x)
    if x > 0
        return x
    else
        return -x
    end
end
"""

measure_code(CyclomaticComplexity(), code)  # 2
measure_code(CognitiveComplexity(),  code)  # 2

# `measure_code(ArgumentCountComplexity(), …)` operates on a single
# function-like expression, so use `measure_report` to score the
# definitions inside a code string:
measure_report(ArgumentCountComplexity(), code)[1].value  # 1

# Per-definition reports
measure_report(CyclomaticComplexity(), read("src/MyModule.jl", String))
measure_report(CognitiveComplexity(),  read("src/MyModule.jl", String);
               max_value = 15)

# Whole-package scans
measure_package(CyclomaticComplexity(), CodeComplexity)
measure_package(CognitiveComplexity(),  "MyPackage")

# Threshold checks (built-in default thresholds — see table above)
check_measure(CyclomaticComplexity(),    MyPackage)                 # 10
check_measure(CognitiveComplexity(),     MyPackage)                 # 15
check_measure(ArgumentCountComplexity(), MyPackage)                 # 5
check_measure(ArgumentCountComplexity(), MyPackage;
              max_value = 7, ignore = (:legacy_api, "@my_macro"))
```

`check_measure` returns the violating files and throws when any exist
unless `throw_on_violation=false`.

## Result types

Both result types are parametric on the metric:

```julia
struct FunctionMeasure{M <: AbstractMetric}
    name::String
    value::Int
    line::Int
end

struct FileMeasure{M <: AbstractMetric}
    path::String
    functions::Vector{FunctionMeasure{M}}
    total_value::Int
end
```

So `measure_file(CognitiveComplexity(), …)` returns
`FileMeasure{CognitiveComplexity}`, etc. The metric is recoverable from
the type alone, and you can dispatch on it.

## Cognitive complexity (Campbell / SonarSource)

Cognitive complexity ([G. Ann Campbell, 2023](https://www.sonarsource.com/resources/cognitive-complexity/);
[white paper PDF](https://www.sonarsource.com/docs/CognitiveComplexity.pdf))
measures how hard a piece of code is to *understand*, as opposed to how
many independent paths it has. It increments for breaks in linear flow,
charges extra for nested flow-break structures, ignores `try` itself but
counts `catch`, collapses runs of like `&&`/`||` into one increment, and
adds one for direct recursion.

```julia
measure_code(CognitiveComplexity(), """
function sumOfPrimes(maxv)
    total = 0
    for i in 1:maxv          # +1
        for j in 2:(i-1)     # +2 (nesting=1)
            if i % j == 0    # +3 (nesting=2)
                @goto out    # +1
            end
        end
        total += i
        @label out
    end
    return total
end
""")  # 7
```

A few Julia-specific notes:

- `cond ? a : b` and `if cond; a; else b end` parse to the *same* `:if` AST node, so the ternary operator is reported as if/else (`+1` for the `if` plus `+1` for the `else`) rather than the spec's single-increment ternary rule.
- Direct recursion is detected by name; **indirect recursion** and calls through dotted names (e.g. `M.foo`) are not counted.
- Comprehensions/generators are walked as plain expressions; nested `if`/`for` *inside* a comprehension do not add structural increments.

## Cyclomatic complexity (McCabe)

Cyclomatic complexity counts **decision points** in the control flow (plus
one). Higher values mean more branches and usually harder-to-test or
harder-to-follow code. The metric counts:

- `if` / `elseif`
- `for` / `while`
- `try` / `catch`
- Short-circuit `&&` / `||`
- Ternary `? :`
- `@goto`

Minimum complexity is 1 (no branches). A single `if` gives 2; each extra
branch adds one.

## Argument count (Ruff PLR0913)

Flag definitions whose **signatures** have more than a chosen number of
parameters (positional slots plus keyword slots), in the spirit of Ruff's
[`PLR0913`](https://docs.astral.sh/ruff/rules/too-many-arguments/) /
Pylint's `lint.pylint.max-args` (default 5).

```julia
measure_report(ArgumentCountComplexity(), code; max_value = 5)
check_measure(ArgumentCountComplexity(), "src/"; max_value = 5)
```

### Ignoring definitions (`ignore`)

Every argument-count entry point accepts an optional `ignore` iterable.
Each entry can be a `Symbol`, an `AbstractString` (use `"@macro"` for
macros), or a callable / type / builtin (matched by `nameof`). Ignored
definitions are dropped **before** the `max_value` filter.

```julia
check_measure(ArgumentCountComplexity(), MyPackage;
              max_value = 5, ignore = (:legacy_api, "@my_macro"))
check_measure(ArgumentCountComplexity(), MyPackage;
              max_value = 5, ignore = (wide_options, MyStruct))
```

**Caveats**

- Matching is by **unqualified name** only: every definition with that name is skipped, even across modules.
- **Macros** usually have no convenient callable to pass; use `Symbol` or `String` with the stored form **`"@macroname"`**.
- **Complex type objects** (e.g. `Union{Int,Nothing}`) use `nameof`; that string may not match a simple identifier in source — prefer symbols or strings when unsure.
- **`->` lambdas** are reported as **`"<anonymous>"`** if you need to ignore them.

## Use in tests and CI

```julia
using Test
using CodeComplexity
import MyPackage

@testset "Complexity" begin
    check_measure(CyclomaticComplexity(),    MyPackage; max_value = 10)
    check_measure(CognitiveComplexity(),     MyPackage; max_value = 15)
    check_measure(ArgumentCountComplexity(), MyPackage; max_value = 5)
end
```

Or scan a directory in a script:

```julia
check_measure(CyclomaticComplexity(), "src/"; max_value = 15)
```

## Migrating from older versions

Two earlier API surfaces (the v1 pre-singleton names and the v2
`*_complexity` verbs) are kept as deprecation shims that forward into
the current API and emit `Base.depwarn` notices. See
[MIGRATIONS.md](MIGRATIONS.md) for the migration map and field-name
compatibility notes.

## Code style (JuliaFormatter)

Formatting is enforced by [JuliaFormatter.jl](https://github.com/domluna/JuliaFormatter.jl) via the [JuliaFormatter](.github/workflows/JuliaFormatter.yml) workflow. Local rules live in [`.JuliaFormatter.toml`](.JuliaFormatter.toml). To format the repo:

```bash
julia -e 'using JuliaFormatter; JuliaFormatter.format(".")'
```

## Aqua.jl

This package uses **[Aqua.jl](https://github.com/JuliaTesting/Aqua.jl)** in
its test suite (`Aqua.test_all(CodeComplexity)`) for general
package-quality checks.

## License

See [LICENSE](LICENSE).
