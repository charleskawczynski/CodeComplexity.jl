# Parameter counts for function-like definitions, in the spirit of Ruff's
# `PLR0913` ("too many arguments") / Pylint's `lint.pylint.max-args` (default 5).
#
# All AST traversal helpers, the `ignore` kwarg pre-filter, and the
# metric-specific `_violation_header` / `_violation_line` overrides live in
# `Internals` (see `src/internals/argument_counts.jl`).

"""
    measure_code(::ArgumentCountComplexity, expr) -> Int

Parameter count of a function-like definition (`function`, short-form `=`,
`->`, `macro`) or of a `:call` / `:tuple` signature. Returns `0` for any
other expression. Each positional slot counts as one; keyword slots inside
`Expr(:parameters, ...)` each contribute one as well.

Aligns with Ruff's [`PLR0913`](https://docs.astral.sh/ruff/rules/too-many-arguments/) /
`lint.pylint.max-args`, not with older Pylint exclusions.
"""
function measure_code(::ArgumentCountComplexity, expr)
    expr isa Expr || return 0
    return Internals._argument_count_for_head(Val(expr.head), expr)
end

measure_code(metric::ArgumentCountComplexity, code::AbstractString) =
    measure_code(metric, Internals._parse_code(code))
