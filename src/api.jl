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
# Nothing here is exported. Users qualify everything via the package, e.g.
# `import CodeComplexity as CC; CC.measure(CC.CyclomaticComplexity(), code)`.

# --- Metric supertype and built-in singletons ------------------------------

"""
    AbstractMetric

Supertype for code-quality metrics. Each metric is a zero-field singleton
used purely for dispatch. Built-in singletons are
[`CyclomaticComplexity`](@ref), [`CognitiveComplexity`](@ref), and
[`ArgumentCountComplexity`](@ref); user-defined metrics subtype
`AbstractMetric` and implement [`measure`](@ref) (plus optionally
[`metric_label`](@ref) / [`default_max_value`](@ref)).
"""
abstract type AbstractMetric end

"""
    CyclomaticComplexity()

McCabe-style decision-point count plus one. See [`measure`](@ref).
"""
struct CyclomaticComplexity <: AbstractMetric end

"""
    CognitiveComplexity()

Campbell / SonarSource cognitive complexity. See [`measure`](@ref).
"""
struct CognitiveComplexity <: AbstractMetric end

"""
    ArgumentCountComplexity()

Parameter count of a function-like definition (Ruff PLR0913-style). See
[`measure`](@ref).
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
    measure(metric::AbstractMetric, expr) -> Int
    measure(metric::AbstractMetric, code::AbstractString) -> Int

Compute `metric`'s score for a single Julia expression (an `Expr` from
`Meta.parse` / `JuliaSyntax`) or a code string. Each metric defines what
"scoring an expression" means; see the per-metric docstrings.

Each metric file provides its own
`measure(::M, ::AbstractString)` one-liner so that the
`(::AbstractMetric, ::AbstractString)` and `(::ConcreteMetric, ::Any)`
signatures do not collide.
"""
function measure end

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
    file_measure(metric, filepath; max_value=nothing, kwargs...)
        -> FileMeasure{typeof(metric)}

Run [`measure_report`](@ref) on the contents of `filepath` and wrap the
results in a [`FileMeasure`](@ref).
"""
function file_measure end

"""
    directory_measure(metric, dirpath;
                      recursive=true, max_value=nothing, kwargs...)
        -> Vector{FileMeasure{typeof(metric)}}

Run [`file_measure`](@ref) on every `.jl` file in `dirpath`. When
`max_value` is set, files with no surviving definitions are excluded.
"""
function directory_measure end

"""
    package_measure(metric, pkg; max_value=nothing, kwargs...)
        -> Vector{FileMeasure{typeof(metric)}}

Run [`directory_measure`](@ref) on a package's `src/` directory. `pkg`
may be a loaded `Module` or a package name string.
"""
function package_measure end

"""
    check_measure(metric, path_or_pkg;
                  max_value=<built-in default>,
                  throw_on_violation=true, kwargs...)
        -> Vector{FileMeasure{typeof(metric)}}

Assert that no definition's `metric` score exceeds `max_value`. Returns
the files containing violations (or empty if none). Throws when
violations are present and `throw_on_violation` is `true`.

For built-in metrics, `max_value` defaults to a conventional threshold
(10 for cyclomatic, 15 for cognitive, 5 for argument count). User-
defined metrics should pass `max_value` explicitly.
"""
function check_measure end
