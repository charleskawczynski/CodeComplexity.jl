# McCabe-style cyclomatic complexity. The score for an expression is the
# number of decision points (`if`/`elseif`, `for`/`while`, `try`/`catch`,
# short-circuit `&&`/`||`, ternary, `@goto`) plus one.
#
# All AST traversal helpers and the metric-specific `_violation_header` /
# `_violation_line` overrides live in `Internals` (see
# `src/internals/cyclomatic.jl`).

"""
    measure_code(::CyclomaticComplexity, expr) -> Int

McCabe cyclomatic complexity (decision points + 1). Minimum is 1.
"""
function measure_code(::CyclomaticComplexity, expr)
    return Internals._cyclomatic_decisions(expr) + 1
end

measure_code(metric::CyclomaticComplexity, code::AbstractString) =
    measure_code(metric, Internals._parse_code(code))
