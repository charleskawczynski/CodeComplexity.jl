module CodeComplexity

using JuliaSyntax

include("ast_utils.jl")
include("cyclomatic_complexity.jl")
include("argument_counts.jl")

export cyclomatic_complexity,
    complexity_report,
    file_complexity,
    directory_complexity,
    package_complexity,
    check_complexity,
    FunctionComplexity,
    FileComplexity,
    argument_count_report,
    file_argument_counts,
    directory_argument_counts,
    package_argument_counts,
    check_argument_count,
    FunctionArguments,
    FileArguments

end # module CodeComplexity
