# Public API surface of CodeComplexity.jl.
#
# This file is intentionally implementation-free: it defines the abstract
# metric supertype, the three built-in metric singletons, the parametric
# result types, and the public verbs as bare `function … end` stubs with
# documentation. Implementations live in `src/common.jl` (shared
# infrastructure) and the per-metric files
# (`cyclomatic_complexity.jl`, `cognitive_complexity.jl`,
# `argument_counts.jl`).
#
# All of the user-facing verbs share a `measure_*` prefix, which lets a
# `using CodeComplexity` user discover them with `measure_<TAB>` at the
# REPL. `check_measure` is the single non-prefix verb because its
# semantics are different (assert / throw rather than return data).
# Previously released names are re-exported from `src/deprecated.jl`.

export
    # Metric supertype + built-in singletons.
    AbstractMetric,
    CyclomaticComplexity,
    CognitiveComplexity,
    ArgumentCountComplexity,
    # Parametric result types.
    FunctionMeasure,
    FileMeasure,
    # Public verbs.
    measure_code,
    measure_report,
    measure_file,
    measure_directory,
    measure_package,
    check_measure,
    measure_check

# --- Metric supertype and built-in singletons ------------------------------

"""
    AbstractMetric

Supertype for the built-in code-quality metrics. Each metric is a
zero-field singleton used purely for dispatch. The built-in singletons
are [`CyclomaticComplexity`](@ref), [`CognitiveComplexity`](@ref), and
[`ArgumentCountComplexity`](@ref).
"""
abstract type AbstractMetric end

"""
    CyclomaticComplexity()

McCabe-style decision-point count plus one. See [`measure_code`](@ref).
"""
struct CyclomaticComplexity <: AbstractMetric end

"""
    CognitiveComplexity()

Campbell / SonarSource cognitive complexity. See [`measure_code`](@ref).
"""
struct CognitiveComplexity <: AbstractMetric end

"""
    ArgumentCountComplexity()

Parameter count of a function-like definition (Ruff PLR0913-style). See
[`measure_code`](@ref).
"""
struct ArgumentCountComplexity <: AbstractMetric end

# --- Result types ----------------------------------------------------------

"""
    FunctionMeasure{M<:AbstractMetric}

Per-definition measurement under metric `M`.

# Fields
- `name::String`: Function or macro name; `"<anonymous>"` for `->` lambdas.
- `value::Int`: The metric's score for this definition.
- `line::Int`: Source line of the definition (`0` if unknown).
"""
struct FunctionMeasure{M <: AbstractMetric}
    name::String
    value::Int
    line::Int
end

"""
    FileMeasure{M<:AbstractMetric}

Per-file summary under metric `M`.

# Fields
- `path::String`: File path.
- `functions::Vector{FunctionMeasure{M}}`: One entry per scanned definition.
- `total_value::Int`: Sum of `value` over `functions`.
"""
struct FileMeasure{M <: AbstractMetric}
    path::String
    functions::Vector{FunctionMeasure{M}}
    total_value::Int
end

# Convenience outer constructors that compute the running total.

function FileMeasure(
    path::AbstractString,
    functions::Vector{FunctionMeasure{M}},
) where {M}
    total = sum(f.value for f in functions; init = 0)
    return FileMeasure{M}(string(path), functions, total)
end

function FileMeasure{M}(
    path::AbstractString,
    functions::Vector{FunctionMeasure{M}},
) where {M <: AbstractMetric}
    total = sum(f.value for f in functions; init = 0)
    return FileMeasure{M}(string(path), functions, total)
end

# --- Public verbs (stubs only — implementations live elsewhere) -----------

"""
    measure_code(metric::AbstractMetric, expr) -> Int
    measure_code(metric::AbstractMetric, code::AbstractString) -> Int

Compute `metric`'s score for a single Julia expression (an `Expr` from
`Meta.parse` / `JuliaSyntax`) or a code string. Each metric defines what
"scoring an expression" means; see the per-metric docstrings.

Each metric file provides its own
`measure_code(::M, ::AbstractString)` one-liner so that the
`(::AbstractMetric, ::AbstractString)` and `(::ConcreteMetric, ::Any)`
signatures do not collide.
"""
function measure_code end

"""
    measure_report(metric, code; max_value=nothing, kwargs...)
        -> Vector{FunctionMeasure{typeof(metric)}}

Run `metric` over every top-level function-like definition in `code` and
return one [`FunctionMeasure`](@ref) per definition. When `max_value` is
set, only definitions with `value > max_value` are returned.

Metric-specific keyword arguments (e.g. `ignore=` for
[`ArgumentCountComplexity`](@ref)) are forwarded to the metric's
pre-filter hook.
"""
function measure_report end

"""
    measure_file(metric, filepath; max_value=nothing, kwargs...)
        -> FileMeasure{typeof(metric)}

Run [`measure_report`](@ref) on the contents of `filepath` and wrap the
results in a [`FileMeasure`](@ref).
"""
function measure_file end

"""
    measure_directory(metric, dirpath;
                      recursive=true, max_value=nothing, kwargs...)
        -> Vector{FileMeasure{typeof(metric)}}

Run [`measure_file`](@ref) on every `.jl` file in `dirpath`. When
`max_value` is set, files with no surviving definitions are excluded.
"""
function measure_directory end

"""
    measure_package(metric, pkg; max_value=nothing, kwargs...)
        -> Vector{FileMeasure{typeof(metric)}}

Run [`measure_directory`](@ref) on a package's `src/` directory. `pkg`
may be a loaded `Module` or a package name string.
"""
function measure_package end

"""
    check_measure(metric, path_or_pkg;
                  max_value=<built-in default>,
                  throw_on_violation=true, kwargs...)
        -> Vector{FileMeasure{typeof(metric)}}

Assert that no definition's `metric` score exceeds `max_value`. Returns
the files containing violations (or empty if none). Throws when
violations are present and `throw_on_violation` is `true`.

`max_value` defaults to a conventional threshold (10 for cyclomatic,
15 for cognitive, 5 for argument count).

The canonical name is `check_measure` (semantics differ from the rest
of the family — it asserts and throws rather than returning data).
[`measure_check`](@ref) is provided as an exact alias so the verb shows
up in `measure_<TAB>` completion alongside the rest of the family.
"""
function check_measure end

"""
    measure_check(metric, path_or_pkg;
                  max_value=<built-in default>,
                  throw_on_violation=true, kwargs...)
        -> Vector{FileMeasure{typeof(metric)}}

Exact alias of [`check_measure`](@ref); see its docstring for full
behaviour. Provided for discoverability so the assert / threshold-check
verb shows up under `measure_<TAB>` at the REPL.
"""
const measure_check = check_measure

# `metric_label` and `default_max_value` are internal-ish traits used
# (respectively) for default error-message formatting and for the
# `check_measure` default threshold; the per-metric methods live in
# `common.jl`. The bare function declarations exist here so the
# `Internals` submodule can `using ..CodeComplexity: metric_label, ...`
# before any methods are added.
function metric_label end
function default_max_value end
