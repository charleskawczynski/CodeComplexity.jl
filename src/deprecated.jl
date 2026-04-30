# Backward-compatibility shims for older API surfaces. Two layers:
#
#   * v1 (pre-singleton) names that were actually released:
#     `cyclomatic_complexity`, `argument_count_report`, the argument-count
#     `file_*` / `directory_*` / `package_*` / `check_*` family, and the
#     type aliases `FunctionArguments` / `FileArguments`.
#
#   * v2 (renamed-but-still-complexity-flavoured) names:
#     `metric_complexity`, `complexity_report`, `file_complexity`,
#     `directory_complexity`, `package_complexity`, `check_complexity`,
#     `FunctionComplexity`, `FileComplexity`.
#
# `CognitiveComplexity` and its API have not been released; they ship for
# the first time alongside the metric-neutral verbs, so they have no
# v1 shims here.
#
# Everything in this file forwards into the v3 unified API in `api.jl` /
# `common.jl` / the per-metric files, with a `Base.depwarn`. New code
# should use `measure_code`, `measure_report`, `measure_file`,
# `measure_directory`, `measure_package`, and `check_measure` with an
# explicit `AbstractMetric` argument.
#
# The metric singletons, parametric result types, and the new `measure_*`
# verbs are exported from `src/api.jl`; this file additionally re-exports
# the previously-released deprecated names plus the two
# previously-exported internal traits (`metric_label`, `default_max_value`)
# so that existing `using CodeComplexity` code continues to work.

export
    # Internal traits (previously exported; new code should treat them
    # as implementation details).
    metric_label,
    default_max_value,
    # v2 result-type aliases and `*_complexity` verbs.
    FunctionComplexity,
    FileComplexity,
    metric_complexity,
    complexity_report,
    file_complexity,
    directory_complexity,
    package_complexity,
    check_complexity,
    # v1 cyclomatic deprecations.
    cyclomatic_complexity,
    # v1 argument-count deprecations.
    argument_count_report,
    file_argument_counts,
    directory_argument_counts,
    package_argument_counts,
    check_argument_count,
    FunctionArguments,
    FileArguments

# --- Type aliases ----------------------------------------------------------

# v1 metric-specific aliases.
const FunctionArguments = FunctionMeasure{ArgumentCountComplexity}
const FileArguments = FileMeasure{ArgumentCountComplexity}

# v2 generic aliases.
const FunctionComplexity = FunctionMeasure
const FileComplexity = FileMeasure

# v1 default constructor (cyclomatic was the original `FunctionComplexity`).
FunctionMeasure(name::AbstractString, value::Integer, line::Integer) =
    FunctionMeasure{CyclomaticComplexity}(string(name), Int(value), Int(line))

# --- Field-access aliases for renamed `value` / `total_value` fields -------
# Old field names (`complexity`, `arg_count`, `total_complexity`,
# `total_arguments`) are forwarded silently so downstream code that reads
# them keeps working.

function Base.getproperty(fc::FunctionMeasure{M}, name::Symbol) where {M}
    if name === :complexity && M === CyclomaticComplexity
        return getfield(fc, :value)
    elseif name === :arg_count && M === ArgumentCountComplexity
        return getfield(fc, :value)
    end
    return getfield(fc, name)
end

function Base.getproperty(fc::FileMeasure{M}, name::Symbol) where {M}
    if name === :total_complexity && M === CyclomaticComplexity
        return getfield(fc, :total_value)
    elseif name === :total_arguments && M === ArgumentCountComplexity
        return getfield(fc, :total_value)
    end
    return getfield(fc, name)
end

function Base.propertynames(fc::FunctionMeasure{M}, private::Bool = false) where {M}
    base = (:name, :value, :line)
    if M === CyclomaticComplexity
        return (base..., :complexity)
    elseif M === ArgumentCountComplexity
        return (base..., :arg_count)
    end
    return base
end

function Base.propertynames(fc::FileMeasure{M}, private::Bool = false) where {M}
    base = (:path, :functions, :total_value)
    if M === CyclomaticComplexity
        return (base..., :total_complexity)
    elseif M === ArgumentCountComplexity
        return (base..., :total_arguments)
    end
    return base
end

# ===========================================================================
# v2 deprecation shims: `*_complexity` verbs forward to the new
# `measure_*` family / `check_measure`.
# ===========================================================================

function metric_complexity(metric::AbstractMetric, x)
    Base.depwarn(
        "`metric_complexity(metric, x)` is deprecated; use " *
        "`measure_code(metric, x)`.",
        :metric_complexity,
    )
    return measure_code(metric, x)
end

function complexity_report(
    metric::AbstractMetric,
    code::AbstractString;
    max_value::Union{Int, Nothing} = nothing,
    kwargs...,
)
    Base.depwarn(
        "`complexity_report(metric, code; ...)` is deprecated; use " *
        "`measure_report(metric, code; ...)`.",
        :complexity_report,
    )
    return measure_report(metric, code; max_value = max_value, kwargs...)
end

function file_complexity(
    metric::AbstractMetric,
    filepath::AbstractString;
    max_value::Union{Int, Nothing} = nothing,
    kwargs...,
)
    Base.depwarn(
        "`file_complexity(metric, path; ...)` is deprecated; use " *
        "`measure_file(metric, path; ...)`.",
        :file_complexity,
    )
    return measure_file(metric, filepath; max_value = max_value, kwargs...)
end

function directory_complexity(
    metric::AbstractMetric,
    dirpath::AbstractString;
    recursive::Bool = true,
    max_value::Union{Int, Nothing} = nothing,
    kwargs...,
)
    Base.depwarn(
        "`directory_complexity(metric, dir; ...)` is deprecated; use " *
        "`measure_directory(metric, dir; ...)`.",
        :directory_complexity,
    )
    return measure_directory(
        metric,
        dirpath;
        recursive = recursive,
        max_value = max_value,
        kwargs...,
    )
end

function package_complexity(
    metric::AbstractMetric,
    pkg;
    max_value::Union{Int, Nothing} = nothing,
    kwargs...,
)
    Base.depwarn(
        "`package_complexity(metric, pkg; ...)` is deprecated; use " *
        "`measure_package(metric, pkg; ...)`.",
        :package_complexity,
    )
    return measure_package(metric, pkg; max_value = max_value, kwargs...)
end

function check_complexity(
    metric::AbstractMetric,
    target;
    max_value::Int = default_max_value(metric),
    throw_on_violation::Bool = true,
    kwargs...,
)
    Base.depwarn(
        "`check_complexity(metric, target; ...)` is deprecated; use " *
        "`check_measure(metric, target; ...)`.",
        :check_complexity,
    )
    return check_measure(
        metric,
        target;
        max_value = max_value,
        throw_on_violation = throw_on_violation,
        kwargs...,
    )
end

# ===========================================================================
# v1 deprecation shims: pre-singleton API.
# ===========================================================================

# --- Cyclomatic deprecations ----------------------------------------------

function cyclomatic_complexity(expr)
    Base.depwarn(
        "`cyclomatic_complexity(expr)` is deprecated; use " *
        "`measure_code(CyclomaticComplexity(), expr)` instead.",
        :cyclomatic_complexity,
    )
    return measure_code(CyclomaticComplexity(), expr)
end

function complexity_report(
    code::AbstractString;
    max_complexity::Union{Int, Nothing} = nothing,
)
    Base.depwarn(
        "`complexity_report(code; max_complexity=...)` is deprecated; use " *
        "`measure_report(CyclomaticComplexity(), code; max_value=...)`.",
        :complexity_report,
    )
    return measure_report(CyclomaticComplexity(), code; max_value = max_complexity)
end

function file_complexity(
    filepath::AbstractString;
    max_complexity::Union{Int, Nothing} = nothing,
)
    Base.depwarn(
        "`file_complexity(path; max_complexity=...)` is deprecated; use " *
        "`measure_file(CyclomaticComplexity(), path; max_value=...)`.",
        :file_complexity,
    )
    return measure_file(CyclomaticComplexity(), filepath; max_value = max_complexity)
end

function directory_complexity(
    dirpath::AbstractString;
    recursive::Bool = true,
    max_complexity::Union{Int, Nothing} = nothing,
)
    Base.depwarn(
        "`directory_complexity(dir; ...)` is deprecated; use " *
        "`measure_directory(CyclomaticComplexity(), dir; max_value=...)`.",
        :directory_complexity,
    )
    return measure_directory(
        CyclomaticComplexity(),
        dirpath;
        recursive = recursive,
        max_value = max_complexity,
    )
end

function package_complexity(
    pkg::Module;
    max_complexity::Union{Int, Nothing} = nothing,
)
    Base.depwarn(
        "`package_complexity(pkg; max_complexity=...)` is deprecated; use " *
        "`measure_package(CyclomaticComplexity(), pkg; max_value=...)`.",
        :package_complexity,
    )
    return measure_package(CyclomaticComplexity(), pkg; max_value = max_complexity)
end

function package_complexity(
    pkg_name::AbstractString;
    max_complexity::Union{Int, Nothing} = nothing,
)
    Base.depwarn(
        "`package_complexity(pkg_name; max_complexity=...)` is deprecated; use " *
        "`measure_package(CyclomaticComplexity(), pkg_name; max_value=...)`.",
        :package_complexity,
    )
    return measure_package(
        CyclomaticComplexity(),
        pkg_name;
        max_value = max_complexity,
    )
end

function check_complexity(
    path::AbstractString;
    max_complexity::Int = default_max_value(CyclomaticComplexity()),
    throw_on_violation::Bool = true,
)
    Base.depwarn(
        "`check_complexity(path; max_complexity=...)` is deprecated; use " *
        "`check_measure(CyclomaticComplexity(), path; max_value=...)`.",
        :check_complexity,
    )
    return check_measure(
        CyclomaticComplexity(),
        path;
        max_value = max_complexity,
        throw_on_violation = throw_on_violation,
    )
end

function check_complexity(
    pkg::Module;
    max_complexity::Int = default_max_value(CyclomaticComplexity()),
    throw_on_violation::Bool = true,
)
    Base.depwarn(
        "`check_complexity(pkg; max_complexity=...)` is deprecated; use " *
        "`check_measure(CyclomaticComplexity(), pkg; max_value=...)`.",
        :check_complexity,
    )
    return check_measure(
        CyclomaticComplexity(),
        pkg;
        max_value = max_complexity,
        throw_on_violation = throw_on_violation,
    )
end

# --- Argument-count deprecations ------------------------------------------

function argument_count_report(
    code::AbstractString;
    max_args::Union{Int, Nothing} = nothing,
    ignore = nothing,
)
    Base.depwarn(
        "`argument_count_report` is deprecated; use " *
        "`measure_report(ArgumentCountComplexity(), code; max_value=..., ignore=...)`.",
        :argument_count_report,
    )
    return measure_report(
        ArgumentCountComplexity(),
        code;
        max_value = max_args,
        ignore = ignore,
    )
end

function file_argument_counts(
    filepath::AbstractString;
    max_args::Union{Int, Nothing} = nothing,
    ignore = nothing,
)
    Base.depwarn(
        "`file_argument_counts` is deprecated; use " *
        "`measure_file(ArgumentCountComplexity(), path; max_value=..., ignore=...)`.",
        :file_argument_counts,
    )
    return measure_file(
        ArgumentCountComplexity(),
        filepath;
        max_value = max_args,
        ignore = ignore,
    )
end

function directory_argument_counts(
    dirpath::AbstractString;
    recursive::Bool = true,
    max_args::Union{Int, Nothing} = nothing,
    ignore = nothing,
)
    Base.depwarn(
        "`directory_argument_counts` is deprecated; use " *
        "`measure_directory(ArgumentCountComplexity(), dir; ...)`.",
        :directory_argument_counts,
    )
    return measure_directory(
        ArgumentCountComplexity(),
        dirpath;
        recursive = recursive,
        max_value = max_args,
        ignore = ignore,
    )
end

function package_argument_counts(
    pkg;
    max_args::Union{Int, Nothing} = nothing,
    ignore = nothing,
)
    Base.depwarn(
        "`package_argument_counts` is deprecated; use " *
        "`measure_package(ArgumentCountComplexity(), pkg; max_value=..., ignore=...)`.",
        :package_argument_counts,
    )
    return measure_package(
        ArgumentCountComplexity(),
        pkg;
        max_value = max_args,
        ignore = ignore,
    )
end

function check_argument_count(
    path_or_pkg;
    max_args::Int = default_max_value(ArgumentCountComplexity()),
    throw_on_violation::Bool = true,
    ignore = nothing,
)
    Base.depwarn(
        "`check_argument_count` is deprecated; use " *
        "`check_measure(ArgumentCountComplexity(), path_or_pkg; max_value=..., ignore=...)`.",
        :check_argument_count,
    )
    return check_measure(
        ArgumentCountComplexity(),
        path_or_pkg;
        max_value = max_args,
        throw_on_violation = throw_on_violation,
        ignore = ignore,
    )
end
