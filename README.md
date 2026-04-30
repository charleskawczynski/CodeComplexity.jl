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

Every entry point dispatches on a metric singleton:

```julia
import CodeComplexity:
    CyclomaticComplexity,
    CognitiveComplexity,
    ArgumentCountComplexity,
    AbstractMetric,
    FunctionMeasure,
    FileMeasure,
    measure,
    measure_report,
    file_measure,
    directory_measure,
    package_measure,
    check_measure
```

The new `measure`-suffixed entry points are intentionally **not**
exported, so new code pulls them in explicitly (above) or qualifies
them via `import CodeComplexity as CC`. The previously-exported
names — the metric singletons, the deprecated `*_complexity` verbs,
the `Function*` / `File*` types, `cyclomatic_complexity`,
`argument_count_report`, … — remain available via
`using CodeComplexity` for backwards compatibility; deprecated verbs
emit `Base.depwarn` notices that point at the new names.

| Singleton | What it measures | Default threshold |
|-----------|------------------|-------------------|
| `CyclomaticComplexity()` | McCabe decision points + 1 | 10 |
| `CognitiveComplexity()` | Sonar / Campbell cognitive complexity | 15 |
| `ArgumentCountComplexity()` | Parameter count of a definition (Ruff PLR0913) | 5 |

All metrics plug into the same six verbs:

```julia
measure(metric, expr_or_code)               # one expression
measure_report(metric, code; max_value=...) # per-definition vector
file_measure(metric, path; max_value=...)   # one file
directory_measure(metric, dir; recursive=true, max_value=...)
package_measure(metric, pkg_or_name; max_value=...)
check_measure(metric, path_or_pkg; max_value=..., throw_on_violation=true)
```

## Quick start

```julia
import CodeComplexity:
    CyclomaticComplexity, CognitiveComplexity, ArgumentCountComplexity,
    measure, measure_report, package_measure, check_measure

code = """
function foo(x)
    if x > 0
        return x
    else
        return -x
    end
end
"""

measure(CyclomaticComplexity(), code)  # 2
measure(CognitiveComplexity(),  code)  # 2

# `measure(ArgumentCountComplexity(), …)` operates on a single function-
# like expression, so use `measure_report` to score the definitions
# inside a code string:
measure_report(ArgumentCountComplexity(), code)[1].value  # 1

# Per-definition reports
measure_report(CyclomaticComplexity(), read("src/MyModule.jl", String))
measure_report(CognitiveComplexity(),  read("src/MyModule.jl", String);
               max_value = 15)

# Whole-package scans
package_measure(CyclomaticComplexity(), CodeComplexity)
package_measure(CognitiveComplexity(),  "MyPackage")

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

So `file_measure(CognitiveComplexity(), …)` returns
`FileMeasure{CognitiveComplexity}`, etc. The metric is recoverable from
the type alone, and you can dispatch on it.

## Cognitive complexity (Campbell / SonarSource)

Cognitive complexity ([G. Ann Campbell, 2023](https://www.sonarsource.com/resources/cognitive-complexity/))
measures how hard a piece of code is to *understand*, as opposed to how
many independent paths it has. It increments for breaks in linear flow,
charges extra for nested flow-break structures, ignores `try` itself but
counts `catch`, collapses runs of like `&&`/`||` into one increment, and
adds one for direct recursion.

```julia
measure(CognitiveComplexity(), """
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

## Adding a new metric

`AbstractMetric` is open: anyone can implement a custom metric by
defining a singleton and a `measure` method. Pass `max_value=`
explicitly when calling `check_measure` on a custom metric.

```julia
import CodeComplexity: AbstractMetric, measure, check_measure

struct LineCount <: AbstractMetric end

function measure(::LineCount, expr)
    expr isa Expr || return 0
    body = length(expr.args) >= 2 ? expr.args[2] : nothing
    return body isa Expr ? count(_ -> true, body.args) : 0
end

check_measure(LineCount(), MyPackage; max_value = 50)
```

You immediately get `measure_report(LineCount(), …)`,
`file_measure(LineCount(), …)`, `directory_measure(LineCount(), …)`,
`package_measure(LineCount(), …)`, and `check_measure(LineCount(), …)`
for free.

## Use in tests and CI

```julia
using Test
import CodeComplexity:
    CyclomaticComplexity, CognitiveComplexity, ArgumentCountComplexity,
    check_measure
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

## Source layout

The package is split into role-based files so adding a metric or piece
of infrastructure has an obvious home:

- `src/api.jl` — abstract type, metric singletons, result types, and the
  public verb stubs with documentation. Implementation-free.
- `src/common.jl` — shared infrastructure: AST extraction, file/
  directory/package walks, threshold checking, error formatting,
  internal trait tables for built-in metrics, and the `Base.show`
  methods.
- `src/cyclomatic_complexity.jl`, `src/cognitive_complexity.jl`,
  `src/argument_counts.jl` — per-metric `measure(::M, expr)` plus any
  metric-specific overrides.
- `src/deprecated.jl` — backward-compatibility shims for older API
  surfaces (see below).

## Deprecated names

Two earlier API surfaces remain available as deprecation shims that
forward to the v3 API and emit `Base.depwarn` notices:

- **v1 (pre-singleton):** `cyclomatic_complexity`, `cognitive_complexity`,
  `cognitive_complexity_report`, `file_cognitive_complexity`, `argument_count_report`,
  `check_argument_count`, `FunctionCognitiveComplexity`, `FileArguments`, …
- **v2 (renamed-but-still-`*_complexity`):** `metric_complexity`,
  `complexity_report`, `file_complexity`, `directory_complexity`,
  `package_complexity`, `check_complexity`, `FunctionComplexity`,
  `FileComplexity`.

Migration map (representative entries; everything in the older surfaces
forwards through the same way):

| Old | New |
|-----|-----|
| `metric_complexity(metric, x)` | `measure(metric, x)` |
| `complexity_report(metric, code; max_value=N)` | `measure_report(metric, code; max_value=N)` |
| `file_complexity(metric, p; max_value=N)` | `file_measure(metric, p; max_value=N)` |
| `directory_complexity(metric, d; …)` | `directory_measure(metric, d; …)` |
| `package_complexity(metric, p; …)` | `package_measure(metric, p; …)` |
| `check_complexity(metric, t; …)` | `check_measure(metric, t; …)` |
| `FunctionComplexity{M}` / `FileComplexity{M}` | `FunctionMeasure{M}` / `FileMeasure{M}` |
| `cyclomatic_complexity(x)` | `measure(CyclomaticComplexity(), x)` |
| `cognitive_complexity(x)` | `measure(CognitiveComplexity(), x)` |
| `argument_count_report(code; max_args=N, ignore=…)` | `measure_report(ArgumentCountComplexity(), code; max_value=N, ignore=…)` |
| `file_cognitive_complexity` / `file_argument_counts` | `file_measure(<metric>, p; …)` |
| `check_cognitive_complexity` / `check_argument_count` | `check_measure(<metric>, …)` |
| `FunctionCognitiveComplexity`, `FileCognitiveComplexity` | `FunctionMeasure{CognitiveComplexity}`, `FileMeasure{CognitiveComplexity}` |
| `FunctionArguments`, `FileArguments` | `FunctionMeasure{ArgumentCountComplexity}`, `FileMeasure{ArgumentCountComplexity}` |

The old field names (`.complexity`, `.arg_count`, `.total_complexity`,
`.total_arguments`) on the parametric types are forwarded transparently
to `.value` / `.total_value` for source compatibility. All deprecated
names are also re-exported, so existing `using CodeComplexity` code
continues to work without modification.

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
