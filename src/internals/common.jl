# Shared helpers used by every metric:
#   * AST → vector-of-FunctionMeasure extraction
#   * file / directory walking utilities
#   * the violation-formatting hooks (`_violation_header`, `_violation_line`)
#   * the `_measure_pre_filter` hook (default no-op; argument count overrides)
#
# Per-metric overrides of these hooks live in the corresponding
# `internals/<metric>.jl` files.

# --- max-value filtering ---------------------------------------------------

function _filter_by_value(
    fns::Vector{FunctionMeasure{M}},
    max_value::Union{Int, Nothing},
) where {M}
    max_value === nothing && return fns
    return filter(f -> f.value > max_value, fns)
end

# Walks the AST looking for function-like definitions and records each as a
# `FunctionMeasure{M}`. The structure is metric-agnostic; only the per-node
# scoring (via `measure`) differs.
function _extract_function_results(
    metric::M,
    expr,
    results::Vector{FunctionMeasure{M}} = FunctionMeasure{M}[],
) where {M <: AbstractMetric}
    expr isa Expr || return results
    if expr.head === :function
        _record_named_definition!(metric, expr, results)
    elseif expr.head === :(=)
        if _is_short_function(expr)
            _record_named_definition!(metric, expr, results)
        else
            for arg in expr.args
                _extract_function_results(metric, arg, results)
            end
        end
    elseif expr.head === :->
        push!(
            results,
            FunctionMeasure{M}(
                "<anonymous>",
                measure(metric, expr),
                _get_line_number(expr),
            ),
        )
    elseif expr.head === :macro
        if length(expr.args) >= 1
            name = "@" * string(_extract_name(expr.args[1]))
            push!(
                results,
                FunctionMeasure{M}(
                    name,
                    measure(metric, expr),
                    _get_line_number(expr),
                ),
            )
        end
    else
        for arg in expr.args
            _extract_function_results(metric, arg, results)
        end
    end
    return results
end

function _record_named_definition!(
    metric::M,
    expr::Expr,
    results::Vector{FunctionMeasure{M}},
) where {M <: AbstractMetric}
    name, is_func = _get_function_name(expr)
    if is_func
        push!(
            results,
            FunctionMeasure{M}(
                name,
                measure(metric, expr),
                _get_line_number(expr),
            ),
        )
    else
        for arg in expr.args
            _extract_function_results(metric, arg, results)
        end
    end
    return results
end

# A short-form function `f(args...) = body` parses as `:(=)` with a `:call`
# (or `:where` wrapping `:call`) on the left. Anything else is a binding.
function _is_short_function(expr::Expr)
    expr.head === :(=) || return false
    length(expr.args) >= 1 || return false
    a1 = expr.args[1]
    a1 isa Expr || return false
    return a1.head === :call || a1.head === :where
end

# --- file / directory walking ---------------------------------------------

function _collect_jl_files(dirpath::AbstractString, recursive::Bool)
    paths = String[]
    if recursive
        for (root, _, files) in walkdir(dirpath)
            for file in files
                endswith(file, ".jl") && push!(paths, joinpath(root, file))
            end
        end
    else
        for file in readdir(dirpath)
            endswith(file, ".jl") || continue
            filepath = joinpath(dirpath, file)
            isfile(filepath) && push!(paths, filepath)
        end
    end
    return paths
end

function _find_package_src_dir(pkg_name::AbstractString)
    for depot in DEPOT_PATH
        pkg_dir = joinpath(depot, "packages", pkg_name)
        if isdir(pkg_dir)
            versions = readdir(pkg_dir)
            if !isempty(versions)
                latest = joinpath(pkg_dir, last(sort(versions)), "src")
                isdir(latest) && return latest
            end
        end
    end
    for path in LOAD_PATH
        path isa AbstractString || continue
        candidate = joinpath(path, pkg_name, "src")
        isdir(candidate) && return candidate
        candidate = joinpath(path, pkg_name)
        isdir(candidate) && return candidate
    end
    return nothing
end

# --- violation reporting ---------------------------------------------------

function _handle_violations(
    metric::AbstractMetric,
    violations::Vector{<:FileMeasure},
    max_value::Int,
    throw_on_violation::Bool,
)
    (throw_on_violation && !isempty(violations)) || return
    msg = IOBuffer()
    println(msg, _violation_header(metric, max_value))
    for fc in violations
        for func in fc.functions
            line_info = func.line > 0 ? ":$(func.line)" : ""
            println(msg, "  ", _violation_line(metric, fc.path, func, line_info))
        end
    end
    error(String(take!(msg)))
end

# Defaults; per-metric files override these to keep the wording stable
# for downstream code that greps for it.
_violation_header(metric::AbstractMetric, max_value) =
    "$(metric_label(metric)) violations (max_value=$max_value):"

_violation_line(::AbstractMetric, path, func, line_info) =
    "$path$line_info: $(func.name) has value $(func.value)"

# --- pre-filter hook -------------------------------------------------------

# Hook each metric can override to drop definitions before max-value
# filtering (e.g. argument count uses this for the `ignore` kwarg).
_measure_pre_filter(::AbstractMetric, fns; kwargs...) = fns
