using Test
using CodeComplexity
using Aqua

@testset "CodeComplexity" begin
    include("cyclomatic_complexity_tests.jl")
    include("argument_counts_tests.jl")
end

@testset "Aqua" begin
    Aqua.test_all(CodeComplexity; deps_compat = (check_extras = false,))
end
