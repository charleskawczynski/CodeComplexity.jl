# Shared infrastructure for every metric. Implements the public verbs
# (`measure_report`, `file_measure`, `directory_measure`, `package_measure`,
# `check_measure`), plus AST extraction, file/directory walking, threshold
# checking, default trait fallbacks, and the `Base.show` methods.
#
# Per-metric files only need to implement `measure(::M, expr)`, optional
# `metric_label(::M)` / `default_max_value(::M)`, and (rarely) override
# `_measure_pre_filter` or `_violation_*` for custom error formatting.

# --- Internal metric traits ------------------------------------------------
#
# `metric_label` supplies the human-readable name used in default error
# messages; `default_max_value` is the threshold `check_measure` falls
# back to when no `max_value` kwarg is passed. Both are implementation
# details: not exported, not part of the documented public API, and only
# defined for built-in metrics. User-defined metrics that want a default
# threshold should pass `max_value=` explicitly to `check_measure`.

metric_label(::CyclomaticComplexity) = "Cyclomatic complexity"
metric_label(::CognitiveComplexity) = "Cognitive complexity"
metric_label(::ArgumentCountComplexity) = "Argument count"

default_max_value(::CyclomaticComplexity) = 10
default_max_value(::CognitiveComplexity) = 15
default_max_value(::ArgumentCountComplexity) = 5

# Hook each metric can override to drop definitions before max-value
# filtering (e.g. argument count uses this for the `ignore` kwarg).
_measure_pre_filter(::AbstractMetric, fns; kwargs...) = fns

# --- measure_report --------------------------------------------------------

function measure_report(
    metric::AbstractMetric,
    code::AbstractString;
    max_value::Union{Int, Nothing} = nothing,
    kwargs...,
)
    expr = _parse_code(code)
    fns = _extract_function_results(metric, expr)
    fns = _measure_pre_filter(metric, fns; kwargs...)
    return _filter_by_value(fns, max_value)
end

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

# --- file / directory / package walks --------------------------------------

function file_measure(
    metric::AbstractMetric,
    filepath::AbstractString;
    max_value::Union{Int, Nothing} = nothing,
    kwargs...,
)
    isfile(filepath) || throw(ArgumentError("File not found: $filepath"))
    code = read(filepath, String)
    fns = measure_report(metric, code; max_value = max_value, kwargs...)
    return FileMeasure(filepath, fns)
end

function directory_measure(
    metric::M,
    dirpath::AbstractString;
    recursive::Bool = true,
    max_value::Union{Int, Nothing} = nothing,
    kwargs...,
) where {M <: AbstractMetric}
    isdir(dirpath) || throw(ArgumentError("Directory not found: $dirpath"))
    results = FileMeasure{M}[]
    for filepath in _collect_jl_files(dirpath, recursive)
        try
            fc = file_measure(metric, filepath; max_value = max_value, kwargs...)
            if max_value === nothing || !isempty(fc.functions)
                push!(results, fc)
            end
        catch e
            @warn "Failed to analyze $filepath" exception = e
        end
    end
    return results
end

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

function package_measure(
    metric::AbstractMetric,
    pkg::Module;
    max_value::Union{Int, Nothing} = nothing,
    kwargs...,
)
    pkg_path = pathof(pkg)
    pkg_path === nothing &&
        throw(ArgumentError("Cannot determine source path for module $pkg"))
    src_dir = dirname(pkg_path)
    return directory_measure(
        metric,
        src_dir;
        recursive = true,
        max_value = max_value,
        kwargs...,
    )
end

function package_measure(
    metric::AbstractMetric,
    pkg_name::AbstractString;
    max_value::Union{Int, Nothing} = nothing,
    kwargs...,
)
    src_dir = _find_package_src_dir(pkg_name)
    src_dir === nothing && throw(ArgumentError("Package not found: $pkg_name"))
    return directory_measure(
        metric,
        src_dir;
        recursive = true,
        max_value = max_value,
        kwargs...,
    )
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

# --- threshold checking ----------------------------------------------------

function check_measure(
    metric::AbstractMetric,
    path::AbstractString;
    max_value::Int = default_max_value(metric),
    throw_on_violation::Bool = true,
    kwargs...,
)
    violations = if isfile(path)
        fc = file_measure(metric, path; max_value = max_value, kwargs...)
        isempty(fc.functions) ? typeof(fc)[] : [fc]
    elseif isdir(path)
        directory_measure(
            metric,
            path;
            recursive = true,
            max_value = max_value,
            kwargs...,
        )
    else
        throw(ArgumentError("Path not found: $path"))
    end
    _handle_violations(metric, violations, max_value, throw_on_violation)
    return violations
end

function check_measure(
    metric::AbstractMetric,
    pkg::Module;
    max_value::Int = default_max_value(metric),
    throw_on_violation::Bool = true,
    kwargs...,
)
    violations = package_measure(metric, pkg; max_value = max_value, kwargs...)
    _handle_violations(metric, violations, max_value, throw_on_violation)
    return violations
end

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

# Default error-message formatting. Per-metric files override these to keep
# the wording stable for downstream code that greps for it.
_violation_header(metric::AbstractMetric, max_value) =
    "$(metric_label(metric)) violations (max_value=$max_value):"

_violation_line(::AbstractMetric, path, func, line_info) =
    "$path$line_info: $(func.name) has value $(func.value)"

# --- show methods ----------------------------------------------------------

function Base.show(io::IO, fc::FunctionMeasure{M}) where {M}
    line_info = fc.line > 0 ? " (line $(fc.line))" : ""
    print(
        io,
        "FunctionMeasure{",
        nameof(M),
        "}(\"",
        fc.name,
        "\", value=",
        fc.value,
        line_info,
        ")",
    )
end

function Base.show(io::IO, ::MIME"text/plain", fc::FileMeasure{M}) where {M}
    println(io, "FileMeasure{", nameof(M), "}: ", fc.path)
    println(io, "  ", metric_label(M()), " total: ", fc.total_value)
    println(io, "  Definitions (", length(fc.functions), "):")
    for func in fc.functions
        line_info = func.line > 0 ? " (line $(func.line))" : ""
        println(io, "    ", func.name, ": ", func.value, line_info)
    end
end
