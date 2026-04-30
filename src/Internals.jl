# All `_`-prefixed implementation helpers live in this submodule so
# they don't pollute `CodeComplexity.<TAB>` completion at the REPL.
# Public verbs in the parent module reach into these helpers via
# qualified `Internals._foo(...)` calls; nothing here is intended to be
# user-facing.
#
# The submodule borrows just the names it needs from the parent —
# metric singletons, the parametric result types, and the public verbs
# whose method tables it dispatches against (`measure`, `metric_label`).
# Methods on those functions (e.g. metric-specific `metric_label`
# overrides) stay in the parent's `common.jl`; per-metric methods of
# the *internal* hooks (`_violation_header`, `_violation_line`,
# `_measure_pre_filter`) live alongside their other helpers below.

module Internals

using JuliaSyntax: parseall

using ..CodeComplexity:
    AbstractMetric,
    CyclomaticComplexity,
    CognitiveComplexity,
    ArgumentCountComplexity,
    FunctionMeasure,
    FileMeasure,
    measure,
    metric_label

include("internals/ast.jl")
include("internals/common.jl")
include("internals/cyclomatic.jl")
include("internals/cognitive.jl")
include("internals/argument_counts.jl")

end # module Internals
