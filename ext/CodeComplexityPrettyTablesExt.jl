module CodeComplexityPrettyTablesExt

using CodeComplexity:
    CodeComplexity, AbstractMetric, FunctionMeasure, FileMeasure, metric_label
using PrettyTables: pretty_table

# Row layout: (file, line, function name, metric value).
const _Row = Tuple{String, Int, String, Int}

function _rows(file::AbstractString, fns::AbstractVector{<:FunctionMeasure})
    return _Row[(string(file), f.line, f.name, f.value) for f in fns]
end

_rows(fm::FileMeasure) = _rows(fm.path, fm.functions)
_rows(f::FunctionMeasure) = _rows("", [f])
_rows(fns::AbstractVector{<:FunctionMeasure}) = _rows("", fns)
function _rows(fms::AbstractVector{<:FileMeasure})
    out = _Row[]
    for fm in fms
        append!(out, _rows(fm))
    end
    return out
end

# Recover the metric singleton from any input shape so the value column
# can be labelled with `metric_label`.
_metric_type(::FunctionMeasure{M}) where {M} = M
_metric_type(::FileMeasure{M}) where {M} = M
_metric_type(::AbstractVector{<:FunctionMeasure{M}}) where {M} = M
_metric_type(::AbstractVector{<:FileMeasure{M}}) where {M} = M

function _to_matrix(rows::Vector{_Row})
    n = length(rows)
    data = Matrix{Any}(undef, n, 4)
    for (i, r) in enumerate(rows)
        data[i, 1] = r[1]
        data[i, 2] = r[2]
        data[i, 3] = r[3]
        data[i, 4] = r[4]
    end
    return data
end

function CodeComplexity.measure_table(
    io::IO,
    x;
    sort_by_value::Bool = true,
    rev::Bool = true,
    kwargs...,
)
    rows = _rows(x)
    if sort_by_value
        sort!(rows; by = r -> r[4], rev = rev)
    end
    labels = ["file", "line", "function", metric_label(_metric_type(x)())]
    return pretty_table(io, _to_matrix(rows); column_labels = labels, kwargs...)
end

CodeComplexity.measure_table(x; kwargs...) =
    CodeComplexity.measure_table(stdout, x; kwargs...)

end # module
