# Cognitive Complexity per G. Ann Campbell, "Cognitive Complexity – a new way of
# measuring understandability" (SonarSource, v1.7, 2023).
#
# Differences from the white paper that are forced by Julia's AST representation:
#   * `cond ? a : b` and `if cond; a; else b end` parse to the same `:if` node, so
#     the ternary operator gets the if/else treatment (`+1` for the if and `+1`
#     for the else) rather than the paper's single-increment ternary rule.
#   * `&&` / `||` are parsed as nested binary nodes; we collapse a chain of
#     identical operators into a single "sequence" so `a && b && c` counts as
#     one increment, while `a && b || c` counts as two (matching the spec).

"""
    measure(::CognitiveComplexity, expr) -> Int

Cognitive complexity (Campbell / SonarSource). Increments come from `if`,
`elseif`, `else`, ternary, `for`/`while`, `catch`, each new sequence of
like short-circuit operators, `@goto`, and direct recursion. Each level of
nesting inside a control-flow structure adds an extra increment. Lambdas
and nested function/macro definitions raise the nesting level for their
body but do not add an increment themselves.
"""
function measure(::CognitiveComplexity, expr)
    return _cognitive_walk(expr, 0, false)
end

measure(metric::CognitiveComplexity, code::AbstractString) =
    measure(metric, _parse_code(code))

# `nesting` is the depth inside structural control-flow; `in_func` is true
# once we are inside a function/lambda body so a further function/lambda is
# treated as nested.
function _cognitive_walk(expr, nesting::Int, in_func::Bool)
    expr isa Expr || return 0
    return _cognitive_for_head(Val(expr.head), expr, nesting, in_func)
end

function _cognitive_walk_args(args, nesting::Int, in_func::Bool)
    c = 0
    for a in args
        c += _cognitive_walk(a, nesting, in_func)
    end
    return c
end

_cognitive_for_head(::Val, expr::Expr, nesting, in_func) =
    _cognitive_walk_args(expr.args, nesting, in_func)

# --- function-like definitions ---------------------------------------------

function _cognitive_for_head(::Val{:function}, expr::Expr, nesting, in_func)
    return _walk_funclike_body(expr, 2, nesting, in_func; check_recursion = true)
end

function _cognitive_for_head(::Val{:macro}, expr::Expr, nesting, in_func)
    return _walk_funclike_body(expr, 2, nesting, in_func; check_recursion = false)
end

function _cognitive_for_head(::Val{:->}, expr::Expr, nesting, in_func)
    return _walk_funclike_body(expr, 2, nesting, in_func; check_recursion = false)
end

function _cognitive_for_head(::Val{:(=)}, expr::Expr, nesting, in_func)
    if _is_short_function(expr)
        return _walk_funclike_body(expr, 2, nesting, in_func; check_recursion = true)
    end
    return _cognitive_walk_args(expr.args, nesting, in_func)
end

function _walk_funclike_body(
    expr::Expr,
    body_idx::Int,
    nesting::Int,
    in_func::Bool;
    check_recursion::Bool,
)
    length(expr.args) >= body_idx || return 0
    body = expr.args[body_idx]
    body_nesting = in_func ? nesting + 1 : nesting
    c = _cognitive_walk(body, body_nesting, true)
    if check_recursion
        name, is_func = _get_function_name(expr)
        if is_func && _has_recursive_call(body, name)
            c += 1
        end
    end
    return c
end

# --- conditionals ----------------------------------------------------------

function _cognitive_for_head(::Val{:if}, expr::Expr, nesting, in_func)
    return _walk_if_like(expr.args, nesting, in_func; structural = true)
end

function _cognitive_for_head(::Val{:elseif}, expr::Expr, nesting, in_func)
    return _walk_if_like(expr.args, nesting, in_func; structural = false)
end

function _walk_if_like(args, nesting::Int, in_func::Bool; structural::Bool)
    n = length(args)
    n >= 1 || return 0
    cond = args[1]
    then_branch = n >= 2 ? args[2] : nothing
    else_branch = n >= 3 ? args[3] : nothing

    has_elif = else_branch isa Expr && else_branch.head === :elseif
    has_else = else_branch !== nothing && !has_elif

    # Structural increment for `if` (subject to nesting); hybrid for `elseif`.
    base = structural ? 1 + nesting : 1
    base += has_else ? 1 : 0

    inner_nesting = nesting + 1
    c = _cognitive_walk(cond, inner_nesting, in_func)
    if then_branch !== nothing
        c += _cognitive_walk(then_branch, inner_nesting, in_func)
    end
    if else_branch !== nothing
        if has_elif
            # `elseif` is at the same nesting (no nesting bump for the keyword).
            c += _cognitive_walk(else_branch, nesting, in_func)
        else
            c += _cognitive_walk(else_branch, inner_nesting, in_func)
        end
    end
    return base + c
end

# --- loops -----------------------------------------------------------------

function _cognitive_for_head(::Val{:for}, expr::Expr, nesting, in_func)
    return _walk_loop(expr.args, nesting, in_func)
end

function _cognitive_for_head(::Val{:while}, expr::Expr, nesting, in_func)
    return _walk_loop(expr.args, nesting, in_func)
end

function _walk_loop(args, nesting::Int, in_func::Bool)
    base = 1 + nesting
    return base + _cognitive_walk_args(args, nesting + 1, in_func)
end

# --- try / catch -----------------------------------------------------------

function _cognitive_for_head(::Val{:try}, expr::Expr, nesting, in_func)
    args = expr.args
    n = length(args)
    c = 0
    if n >= 1 && args[1] isa Expr
        c += _cognitive_walk(args[1], nesting, in_func)
    end
    if n >= 3 && args[3] isa Expr
        # +1 (subject to nesting) for the catch; nesting+1 for the catch body.
        c += 1 + nesting
        c += _cognitive_walk(args[3], nesting + 1, in_func)
    end
    if n >= 4 && args[4] isa Expr
        c += _cognitive_walk(args[4], nesting, in_func)
    end
    if n >= 5 && args[5] isa Expr
        c += _cognitive_walk(args[5], nesting, in_func)
    end
    return c
end

# --- short-circuit boolean sequences ---------------------------------------

function _cognitive_for_head(::Val{:&&}, expr::Expr, nesting, in_func)
    return _walk_boolop_sequence(expr, nesting, in_func, expr.head; new_sequence = true)
end

function _cognitive_for_head(::Val{:||}, expr::Expr, nesting, in_func)
    return _walk_boolop_sequence(expr, nesting, in_func, expr.head; new_sequence = true)
end

# Counts each maximal run of identical short-circuit operators as one
# fundamental increment, matching the white paper's "sequence of like
# binary boolean operators" rule.
function _walk_boolop_sequence(
    expr::Expr,
    nesting::Int,
    in_func::Bool,
    seq_head::Symbol;
    new_sequence::Bool,
)
    c = new_sequence ? 1 : 0
    for a in expr.args
        if a isa Expr && (a.head === :&& || a.head === :||)
            if a.head === seq_head
                c += _walk_boolop_sequence(
                    a,
                    nesting,
                    in_func,
                    seq_head;
                    new_sequence = false,
                )
            else
                c += _walk_boolop_sequence(
                    a,
                    nesting,
                    in_func,
                    a.head;
                    new_sequence = true,
                )
            end
        else
            c += _cognitive_walk(a, nesting, in_func)
        end
    end
    return c
end

# --- @goto and other macro calls -------------------------------------------

function _cognitive_for_head(::Val{:macrocall}, expr::Expr, nesting, in_func)
    args = expr.args
    c = 0
    if !isempty(args) && args[1] === Symbol("@goto")
        c += 1
    end
    # args[1] is the macro name and args[2] is a LineNumberNode; only walk the
    # macro arguments themselves.
    for i in 3:length(args)
        c += _cognitive_walk(args[i], nesting, in_func)
    end
    return c
end

# --- recursion detection ---------------------------------------------------

function _has_recursive_call(body, name::AbstractString)
    isempty(name) && return false
    occursin(".", name) && return false
    target = Symbol(name)
    return _contains_call_to(body, target)
end

function _contains_call_to(expr, target::Symbol)
    expr isa Expr || return false
    if expr.head === :call &&
       length(expr.args) >= 1 &&
       expr.args[1] === target
        return true
    end
    for a in expr.args
        _contains_call_to(a, target) && return true
    end
    return false
end

# --- error-message overrides ----------------------------------------------

_violation_header(::CognitiveComplexity, max_value) =
    "Cognitive complexity violations (max_complexity=$max_value):"

_violation_line(::CognitiveComplexity, path, func, line_info) =
    "$path$line_info: $(func.name) has complexity $(func.value)"
