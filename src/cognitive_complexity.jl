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
#
# All AST traversal helpers and the metric-specific `_violation_header` /
# `_violation_line` overrides live in `Internals` (see
# `src/internals/cognitive.jl`).

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
    return Internals._cognitive_walk(expr, 0, false)
end

measure(metric::CognitiveComplexity, code::AbstractString) =
    measure(metric, Internals._parse_code(code))
