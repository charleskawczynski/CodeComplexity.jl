module CodeComplexity

using JuliaSyntax

include("ast_utils.jl")
include("api.jl")
include("common.jl")
include("cyclomatic_complexity.jl")
include("cognitive_complexity.jl")
include("argument_counts.jl")
include("deprecated.jl")

# Nothing is exported. Users qualify everything via the package, e.g.
#     import CodeComplexity as CC
#     CC.measure(CC.CyclomaticComplexity(), code)

end # module CodeComplexity
