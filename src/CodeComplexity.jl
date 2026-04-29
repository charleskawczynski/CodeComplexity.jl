module CodeComplexity

using JuliaSyntax

include("ast_utils.jl")
include("cyclomatic_complexity.jl")
include("argument_counts.jl")
include("cognitive_complexity.jl")

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
    FileArguments,
    cognitive_complexity,
    cognitive_complexity_report,
    file_cognitive_complexity,
    directory_cognitive_complexity,
    package_cognitive_complexity,
    check_cognitive_complexity,
    FunctionCognitiveComplexity,
    FileCognitiveComplexity

end # module CodeComplexity
