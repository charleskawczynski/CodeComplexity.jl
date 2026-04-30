# McCabe-style cyclomatic complexity. The score for an expression is the
# number of decision points (`if`/`elseif`, `for`/`while`, `try`/`catch`,
# short-circuit `&&`/`||`, ternary, `@goto`) plus one.

"""
    measure(::CyclomaticComplexity, expr) -> Int

McCabe cyclomatic complexity (decision points + 1). Minimum is 1.
"""
function measure(::CyclomaticComplexity, expr)
    return _cyclomatic_decisions(expr) + 1
end

measure(metric::CyclomaticComplexity, code::AbstractString) =
    measure(metric, _parse_code(code))

function _cyclomatic_decisions(expr)
    expr isa Expr || return 0
    return _cyclomatic_for_head(Val(expr.head), expr.args)
end

function _cyclomatic_sum_args(args)
    n = 0
    for arg in args
        n += _cyclomatic_decisions(arg)
    end
    return n
end

_cyclomatic_for_head(::Val, args) = _cyclomatic_sum_args(args)

_cyclomatic_for_head(::Val{:if}, args) = 1 + _cyclomatic_sum_args(args)
_cyclomatic_for_head(::Val{:elseif}, args) = 1 + _cyclomatic_sum_args(args)
_cyclomatic_for_head(::Val{:for}, args) = 1 + _cyclomatic_sum_args(args)
_cyclomatic_for_head(::Val{:while}, args) = 1 + _cyclomatic_sum_args(args)
_cyclomatic_for_head(::Val{:catch}, args) = 1 + _cyclomatic_sum_args(args)
_cyclomatic_for_head(::Val{:&&}, args) = 1 + _cyclomatic_sum_args(args)
_cyclomatic_for_head(::Val{:||}, args) = 1 + _cyclomatic_sum_args(args)
_cyclomatic_for_head(::Val{:?}, args) = 1 + _cyclomatic_sum_args(args)

# `:try` is a five-position node (try-body, exc-name, catch-body, finally,
# else); `args[3]` is `false` when there is no `catch`. We only add +1 when a
# catch is present.
function _cyclomatic_for_head(::Val{:try}, args)
    n = 0
    for (i, arg) in enumerate(args)
        if arg isa Expr
            n += _cyclomatic_decisions(arg)
        elseif arg isa Symbol && i == 2
            if length(args) >= 3 && args[3] !== false
                n += 1
            end
        end
    end
    if length(args) >= 3 && args[3] !== false && !(args[2] isa Symbol)
        n += 1
    end
    return n
end

# Only `@goto` increments cyclomatic complexity among macros.
function _cyclomatic_for_head(::Val{:macrocall}, args)
    n = 0
    if length(args) > 0 && args[1] === Symbol("@goto")
        n += 1
    end
    for arg in args[3:end]
        n += _cyclomatic_decisions(arg)
    end
    return n
end

# --- error-message overrides ----------------------------------------------
#
# Cyclomatic violations historically use `max_complexity=` and the word
# "complexity" in the message. Preserve that wording so downstream code (and
# our own tests) that grep for it keeps working.

_violation_header(::CyclomaticComplexity, max_value) =
    "Cyclomatic complexity violations (max_complexity=$max_value):"

_violation_line(::CyclomaticComplexity, path, func, line_info) =
    "$path$line_info: $(func.name) has complexity $(func.value)"
