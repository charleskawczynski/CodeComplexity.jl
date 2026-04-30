# Backward-compatibility shims for older API surfaces. Two layers:
#
#   * v1 (pre-singleton) names: `cyclomatic_complexity`,
#     `cognitive_complexity[_report]`, `argument_count_report`, `file_*`,
#     `directory_*`, `package_*`, `check_*`, plus the type aliases
#     `FunctionCognitiveComplexity`, `FileCognitiveComplexity`,
#     `FunctionArguments`, `FileArguments`.
#
#   * v2 (renamed-but-still-complexity-flavoured) names:
#     `metric_complexity`, `complexity_report`, `file_complexity`,
#     `directory_complexity`, `package_complexity`, `check_complexity`,
#     `FunctionComplexity`, `FileComplexity`.
#
# Everything in this file forwards into the v3 unified API in `api.jl` /
# `common.jl` / the per-metric files, with a `Base.depwarn`. New code
# should use `measure`, `measure_report`, `file_measure`,
# `directory_measure`, `package_measure`, and `check_measure` with an
# explicit `AbstractMetric` argument. Nothing in this file is exported.

# --- Type aliases ----------------------------------------------------------

# v1 metric-specific aliases.
const FunctionCognitiveComplexity = FunctionMeasure{CognitiveComplexity}
const FileCognitiveComplexity = FileMeasure{CognitiveComplexity}
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
    if name === :complexity && (M === CyclomaticComplexity || M === CognitiveComplexity)
        return getfield(fc, :value)
    elseif name === :arg_count && M === ArgumentCountComplexity
        return getfield(fc, :value)
    end
    return getfield(fc, name)
end

function Base.getproperty(fc::FileMeasure{M}, name::Symbol) where {M}
    if name === :total_complexity &&
       (M === CyclomaticComplexity || M === CognitiveComplexity)
        return getfield(fc, :total_value)
    elseif name === :total_arguments && M === ArgumentCountComplexity
        return getfield(fc, :total_value)
    end
    return getfield(fc, name)
end

function Base.propertynames(fc::FunctionMeasure{M}, private::Bool = false) where {M}
    base = (:name, :value, :line)
    if M === CyclomaticComplexity || M === CognitiveComplexity
        return (base..., :complexity)
    elseif M === ArgumentCountComplexity
        return (base..., :arg_count)
    end
    return base
end

function Base.propertynames(fc::FileMeasure{M}, private::Bool = false) where {M}
    base = (:path, :functions, :total_value)
    if M === CyclomaticComplexity || M === CognitiveComplexity
        return (base..., :total_complexity)
    elseif M === ArgumentCountComplexity
        return (base..., :total_arguments)
    end
    return base
end

# ===========================================================================
# v2 deprecation shims: `*_complexity` verbs forward to `*_measure` /
# `measure` / `measure_report`.
# ===========================================================================

function metric_complexity(metric::AbstractMetric, x)
    Base.depwarn(
        "`metric_complexity(metric, x)` is deprecated; use " *
        "`measure(metric, x)`.",
        :metric_complexity,
    )
    return measure(metric, x)
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
        "`file_measure(metric, path; ...)`.",
        :file_complexity,
    )
    return file_measure(metric, filepath; max_value = max_value, kwargs...)
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
        "`directory_measure(metric, dir; ...)`.",
        :directory_complexity,
    )
    return directory_measure(
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
        "`package_measure(metric, pkg; ...)`.",
        :package_complexity,
    )
    return package_measure(metric, pkg; max_value = max_value, kwargs...)
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
        "`measure(CyclomaticComplexity(), expr)` instead.",
        :cyclomatic_complexity,
    )
    return measure(CyclomaticComplexity(), expr)
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
        "`file_measure(CyclomaticComplexity(), path; max_value=...)`.",
        :file_complexity,
    )
    return file_measure(CyclomaticComplexity(), filepath; max_value = max_complexity)
end

function directory_complexity(
    dirpath::AbstractString;
    recursive::Bool = true,
    max_complexity::Union{Int, Nothing} = nothing,
)
    Base.depwarn(
        "`directory_complexity(dir; ...)` is deprecated; use " *
        "`directory_measure(CyclomaticComplexity(), dir; max_value=...)`.",
        :directory_complexity,
    )
    return directory_measure(
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
        "`package_measure(CyclomaticComplexity(), pkg; max_value=...)`.",
        :package_complexity,
    )
    return package_measure(CyclomaticComplexity(), pkg; max_value = max_complexity)
end

function package_complexity(
    pkg_name::AbstractString;
    max_complexity::Union{Int, Nothing} = nothing,
)
    Base.depwarn(
        "`package_complexity(pkg_name; max_complexity=...)` is deprecated; use " *
        "`package_measure(CyclomaticComplexity(), pkg_name; max_value=...)`.",
        :package_complexity,
    )
    return package_measure(
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

# --- Cognitive deprecations -----------------------------------------------

function cognitive_complexity(expr_or_code)
    Base.depwarn(
        "`cognitive_complexity(x)` is deprecated; use " *
        "`measure(CognitiveComplexity(), x)`.",
        :cognitive_complexity,
    )
    return measure(CognitiveComplexity(), expr_or_code)
end

function cognitive_complexity_report(
    code::AbstractString;
    max_complexity::Union{Int, Nothing} = nothing,
)
    Base.depwarn(
        "`cognitive_complexity_report` is deprecated; use " *
        "`measure_report(CognitiveComplexity(), code; max_value=...)`.",
        :cognitive_complexity_report,
    )
    return measure_report(CognitiveComplexity(), code; max_value = max_complexity)
end

function file_cognitive_complexity(
    filepath::AbstractString;
    max_complexity::Union{Int, Nothing} = nothing,
)
    Base.depwarn(
        "`file_cognitive_complexity` is deprecated; use " *
        "`file_measure(CognitiveComplexity(), path; max_value=...)`.",
        :file_cognitive_complexity,
    )
    return file_measure(CognitiveComplexity(), filepath; max_value = max_complexity)
end

function directory_cognitive_complexity(
    dirpath::AbstractString;
    recursive::Bool = true,
    max_complexity::Union{Int, Nothing} = nothing,
)
    Base.depwarn(
        "`directory_cognitive_complexity` is deprecated; use " *
        "`directory_measure(CognitiveComplexity(), dir; ...)`.",
        :directory_cognitive_complexity,
    )
    return directory_measure(
        CognitiveComplexity(),
        dirpath;
        recursive = recursive,
        max_value = max_complexity,
    )
end

function package_cognitive_complexity(
    pkg;
    max_complexity::Union{Int, Nothing} = nothing,
)
    Base.depwarn(
        "`package_cognitive_complexity` is deprecated; use " *
        "`package_measure(CognitiveComplexity(), pkg; max_value=...)`.",
        :package_cognitive_complexity,
    )
    return package_measure(CognitiveComplexity(), pkg; max_value = max_complexity)
end

function check_cognitive_complexity(
    path_or_pkg;
    max_complexity::Int = default_max_value(CognitiveComplexity()),
    throw_on_violation::Bool = true,
)
    Base.depwarn(
        "`check_cognitive_complexity` is deprecated; use " *
        "`check_measure(CognitiveComplexity(), path_or_pkg; max_value=...)`.",
        :check_cognitive_complexity,
    )
    return check_measure(
        CognitiveComplexity(),
        path_or_pkg;
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
        "`file_measure(ArgumentCountComplexity(), path; max_value=..., ignore=...)`.",
        :file_argument_counts,
    )
    return file_measure(
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
        "`directory_measure(ArgumentCountComplexity(), dir; ...)`.",
        :directory_argument_counts,
    )
    return directory_measure(
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
        "`package_measure(ArgumentCountComplexity(), pkg; max_value=..., ignore=...)`.",
        :package_argument_counts,
    )
    return package_measure(
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
