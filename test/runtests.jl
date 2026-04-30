using Test
import CodeComplexity as CC
using Aqua

@testset "CodeComplexity" begin
    include("new_api_tests.jl")
    include("cyclomatic_complexity_tests.jl")
    include("argument_counts_tests.jl")
    include("cognitive_complexity_tests.jl")
    include("deprecation_tests.jl")
end

@testset "Aqua" begin
    Aqua.test_all(CC; deps_compat = (check_extras = false,))
end
