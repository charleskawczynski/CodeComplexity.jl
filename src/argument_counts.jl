# Parameter counts for function-like definitions, in the spirit of Ruff's
# `PLR0913` ("too many arguments") / Pylint's `lint.pylint.max-args` (default 5).

"""
    measure(::ArgumentCountComplexity, expr) -> Int

Parameter count of a function-like definition (`function`, short-form `=`,
`->`, `macro`) or of a `:call` / `:tuple` signature. Returns `0` for any
other expression. Each positional slot counts as one; keyword slots inside
`Expr(:parameters, ...)` each contribute one as well.

Aligns with Ruff's [`PLR0913`](https://docs.astral.sh/ruff/rules/too-many-arguments/) /
`lint.pylint.max-args`, not with older Pylint exclusions.
"""
function measure(::ArgumentCountComplexity, expr)
    expr isa Expr || return 0
    return _argument_count_for_head(Val(expr.head), expr)
end

measure(metric::ArgumentCountComplexity, code::AbstractString) =
    measure(metric, _parse_code(code))

_argument_count_for_head(::Val, ::Expr) = 0

_argument_count_for_head(::Val{:function}, expr::Expr) =
    _argument_count_long_function(expr)

_argument_count_for_head(::Val{:macro}, expr::Expr) = _argument_count_macro(expr)

_argument_count_for_head(::Val{:->}, expr::Expr) = _argument_count_lambda(expr)

function _argument_count_for_head(::Val{:(=)}, expr::Expr)
    _is_short_function(expr) || return 0
    return _argument_count_short_function(expr)
end

_argument_count_for_head(::Val{:call}, expr::Expr) = _count_call_parameters(expr)
_argument_count_for_head(::Val{:tuple}, expr::Expr) = _count_tuple_parameters(expr)

function _unwrap_where(sig)
    while sig isa Expr && sig.head === :where && !isempty(sig.args)
        sig = sig.args[1]
    end
    return sig
end

# Count parameters in `Expr(:call, f, args...)` after `f`: each positional
# slot counts as one; `Expr(:parameters, ...)` contributes one per keyword
# slot inside.
function _count_call_parameters(call::Expr)
    (call.head === :call && length(call.args) >= 1) || return 0
    n = 0
    for i in 2:length(call.args)
        a = call.args[i]
        if a isa Expr && a.head === :parameters
            n += length(a.args)
        else
            n += 1
        end
    end
    return n
end

function _count_tuple_parameters(tup::Expr)
    tup.head === :tuple || return 0
    n = 0
    for a in tup.args
        if a isa Expr && a.head === :parameters
            n += length(a.args)
        else
            n += 1
        end
    end
    return n
end

function _argument_count_long_function(expr::Expr)
    length(expr.args) < 1 && return 0
    sig = _unwrap_where(expr.args[1])
    sig isa Symbol && return 0
    if sig isa Expr && sig.head === :call
        return _count_call_parameters(sig)
    end
    return 0
end

function _argument_count_short_function(expr::Expr)
    length(expr.args) < 1 && return 0
    sig = _unwrap_where(expr.args[1])
    if sig isa Expr && sig.head === :call
        return _count_call_parameters(sig)
    end
    return 0
end

function _argument_count_lambda(expr::Expr)
    length(expr.args) < 1 && return 0
    sig = _unwrap_where(expr.args[1])
    sig isa Symbol && return 1
    if sig isa Expr && sig.head === :call
        return _count_call_parameters(sig)
    end
    if sig isa Expr && sig.head === :tuple
        return _count_tuple_parameters(sig)
    end
    return 0
end

function _argument_count_macro(expr::Expr)
    length(expr.args) < 1 && return 0
    sig = _unwrap_where(expr.args[1])
    sig isa Symbol && return 0
    if sig isa Expr && sig.head === :call
        return _count_call_parameters(sig)
    end
    return 0
end

# --- ignore kwarg handling -------------------------------------------------

function _argument_ignore_key(x)::String
    if x isa Symbol || x isa AbstractString
        return string(x)
    elseif applicable(nameof, x)
        return string(nameof(x))
    else
        return string(x)
    end
end

function _argument_ignore_set(ignore)::Union{Nothing, Set{String}}
    ignore === nothing && return nothing
    return Set{String}(_argument_ignore_key(x) for x in ignore)
end

# Hook into the generic pipeline (see `_measure_pre_filter` in common.jl) so
# that `measure_report(ArgumentCountComplexity(), code; ignore=...)` drops
# named definitions before any `max_value` filtering.
function _measure_pre_filter(
    ::ArgumentCountComplexity,
    fns::Vector{FunctionMeasure{ArgumentCountComplexity}};
    ignore = nothing,
    kwargs...,
)
    ignore_set = _argument_ignore_set(ignore)
    (ignore_set === nothing || isempty(ignore_set)) && return fns
    return filter(f -> !(f.name in ignore_set), fns)
end

# --- error-message overrides ----------------------------------------------

_violation_header(::ArgumentCountComplexity, max_value) =
    "Too-many-arguments violations (max_args=$max_value; PLR0913-style):"

_violation_line(::ArgumentCountComplexity, path, func, line_info) =
    "$path$line_info: $(func.name) has $(func.value) parameters"
