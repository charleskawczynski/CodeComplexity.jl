using Test
using CodeComplexity
using Aqua

@testset "CodeComplexity" begin
    @test 1 == 1
end

@testset "Aqua" begin
    Aqua.test_all(CodeComplexity)
end
