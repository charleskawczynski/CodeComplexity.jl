module CodeComplexity

using JuliaSyntax

# Public API surface (types, stubs, docstrings).
include("api.jl")

# All `_`-prefixed implementation helpers — kept in a submodule so
# `CodeComplexity.<TAB>` only exposes user-facing names. Must be loaded
# *after* `api.jl` (so the types/function names exist for `using
# ..CodeComplexity: …`) and *before* the parent-module verb files (which
# call `Internals._foo`).
include("Internals.jl")

# Public verb implementations (call into `Internals` for the heavy lifting).
include("common.jl")
include("cyclomatic_complexity.jl")
include("cognitive_complexity.jl")
include("argument_counts.jl")

# Backward-compatibility shims for v1/v2 names. Re-exports the previously
# exported public surface; the new names stay unexported.
include("deprecated.jl")

end # module CodeComplexity
