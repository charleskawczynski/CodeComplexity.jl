# Public verbs that aren't tied to a single metric: `measure_report`,
# `measure_file`, `measure_directory`, `measure_package`, `check_measure`,
# the per-metric `metric_label` / `default_max_value` lookups, and the
# `Base.show` methods. All of the AST walking, file/directory traversal,
# and violation formatting lives in `Internals` (see `src/Internals.jl`
# and `src/internals/*.jl`).

# --- metric traits ---------------------------------------------------------
#
# `metric_label` supplies the human-readable name used in default error
# messages; `default_max_value` is the threshold `check_measure` falls
# back to when no `max_value` kwarg is passed. Both are intended to stay
# implementation details: not part of the documented public API, and
# re-exported only for backward compatibility from `src/deprecated.jl`.

metric_label(::CyclomaticComplexity) = "Cyclomatic complexity"
metric_label(::CognitiveComplexity) = "Cognitive complexity"
metric_label(::ArgumentCountComplexity) = "Argument count"

default_max_value(::CyclomaticComplexity) = 10
default_max_value(::CognitiveComplexity) = 15
default_max_value(::ArgumentCountComplexity) = 5

# --- measure_report --------------------------------------------------------

function measure_report(
    metric::AbstractMetric,
    code::AbstractString;
    max_value::Union{Int, Nothing} = nothing,
    kwargs...,
)
    expr = Internals._parse_code(code)
    fns = Internals._extract_function_results(metric, expr)
    fns = Internals._measure_pre_filter(metric, fns; kwargs...)
    return Internals._filter_by_value(fns, max_value)
end

# --- file / directory / package walks --------------------------------------

function measure_file(
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

function measure_directory(
    metric::M,
    dirpath::AbstractString;
    recursive::Bool = true,
    max_value::Union{Int, Nothing} = nothing,
    kwargs...,
) where {M <: AbstractMetric}
    isdir(dirpath) || throw(ArgumentError("Directory not found: $dirpath"))
    results = FileMeasure{M}[]
    for filepath in Internals._collect_jl_files(dirpath, recursive)
        try
            fc = measure_file(metric, filepath; max_value = max_value, kwargs...)
            if max_value === nothing || !isempty(fc.functions)
                push!(results, fc)
            end
        catch e
            @warn "Failed to analyze $filepath" exception = e
        end
    end
    return results
end

function measure_package(
    metric::AbstractMetric,
    pkg::Module;
    max_value::Union{Int, Nothing} = nothing,
    kwargs...,
)
    pkg_path = pathof(pkg)
    pkg_path === nothing &&
        throw(ArgumentError("Cannot determine source path for module $pkg"))
    src_dir = dirname(pkg_path)
    return measure_directory(
        metric,
        src_dir;
        recursive = true,
        max_value = max_value,
        kwargs...,
    )
end

function measure_package(
    metric::AbstractMetric,
    pkg_name::AbstractString;
    max_value::Union{Int, Nothing} = nothing,
    kwargs...,
)
    src_dir = Internals._find_package_src_dir(pkg_name)
    src_dir === nothing && throw(ArgumentError("Package not found: $pkg_name"))
    return measure_directory(
        metric,
        src_dir;
        recursive = true,
        max_value = max_value,
        kwargs...,
    )
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
        fc = measure_file(metric, path; max_value = max_value, kwargs...)
        isempty(fc.functions) ? typeof(fc)[] : [fc]
    elseif isdir(path)
        measure_directory(
            metric,
            path;
            recursive = true,
            max_value = max_value,
            kwargs...,
        )
    else
        throw(ArgumentError("Path not found: $path"))
    end
    Internals._handle_violations(metric, violations, max_value, throw_on_violation)
    return violations
end

function check_measure(
    metric::AbstractMetric,
    pkg::Module;
    max_value::Int = default_max_value(metric),
    throw_on_violation::Bool = true,
    kwargs...,
)
    violations = measure_package(metric, pkg; max_value = max_value, kwargs...)
    Internals._handle_violations(metric, violations, max_value, throw_on_violation)
    return violations
end

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
