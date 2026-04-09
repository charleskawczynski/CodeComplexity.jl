# Included from runtests.jl — PLR0913-style parameter counts and check_argument_count.

@testset "Argument count (PLR0913-style)" begin
    @testset "argument_count_report counting" begin
        code = """
        function six_pos(a, b, c, d, e, f)
            return nothing
        end
        function kwonly(x; p = 1, q = 2)
            return x
        end
        function mixed(a, b; c = 1)
            return a
        end
        function wheref(x::T) where {T}
            return x
        end
        function zeroary()
            return 1
        end
        function barename end
        short(x, y) = x + y
        f() = 1
        function splat(args...)
            return args
        end
        function typedonly(::Int, y)
            return y
        end
        macro mac2(x, y)
            return esc(x)
        end
        """
        r = argument_count_report(code)
        byname = Dict(f.name => f.arg_count for f in r)
        @test byname["six_pos"] == 6
        @test byname["kwonly"] == 3
        @test byname["mixed"] == 3
        @test byname["wheref"] == 1
        @test byname["zeroary"] == 0
        @test byname["barename"] == 0
        @test byname["short"] == 2
        @test byname["f"] == 0
        @test byname["splat"] == 1
        @test byname["typedonly"] == 2
        @test byname["@mac2"] == 2
    end

    @testset "argument_count_report lambda lhs shapes" begin
        r = argument_count_report(
            "(t, u) -> t + u\nw -> w\ng(a, b) -> a\n(a, b; c = 1) -> a\n",
        )
        @test sort([x.arg_count for x in r]) == [1, 2, 2, 3]
    end

    @testset "argument_count_report anonymous definitions" begin
        code = """
        (a, b) -> a + b
        x -> x
        """
        r = argument_count_report(code)
        @test length(r) == 2
        counts = sort([f.arg_count for f in r])
        @test counts == [1, 2]
    end

    @testset "max_args filtering" begin
        code = "function many(a,b,c,d,e,f) end\nfunction few(a) end\n"
        allf = argument_count_report(code)
        @test length(allf) == 2
        viol = argument_count_report(code; max_args = 5)
        @test length(viol) == 1
        @test viol[1].name == "many"
        @test viol[1].arg_count == 6
    end

    @testset "FunctionArguments and FileArguments" begin
        fa = FunctionArguments("g", 7, 3)
        @test fa.name == "g" && fa.arg_count == 7 && fa.line == 3
        fl = FileArguments(
            "x.jl",
            [FunctionArguments("g", 2, 1), FunctionArguments("h", 3, 2)],
        )
        @test fl.path == "x.jl"
        @test fl.total_arguments == 5
    end

    @testset "file_argument_counts and check_argument_count" begin
        mktempdir() do tmpdir
            file = joinpath(tmpdir, "sig.jl")
            write(
                file,
                """
function ok(a, b, c)
    return a + b + c
end
function bad(a, b, c, d, e, f)
    return 0
end
""",
            )
            fa = file_argument_counts(file)
            @test length(fa.functions) == 2
            @test fa.total_arguments == 9

            fa_v = file_argument_counts(file; max_args = 5)
            @test length(fa_v.functions) == 1
            @test fa_v.functions[1].name == "bad"

            @test_throws ErrorException check_argument_count(file; max_args = 5)
            v = check_argument_count(file; max_args = 5, throw_on_violation = false)
            @test length(v) == 1
            @test v[1].functions[1].name == "bad"

            @test isempty(check_argument_count(file; max_args = 6))
        end
    end

    @testset "check_argument_count error message" begin
        mktempdir() do tmpdir
            file = joinpath(tmpdir, "t.jl")
            write(file, "function z(a,b,c,d,e,f) end\n")
            err = try
                check_argument_count(file; max_args = 5)
                nothing
            catch e
                e
            end
            @test err !== nothing
            @test occursin("Too-many-arguments", err.msg)
            @test occursin("max_args=5", err.msg)
            @test occursin("z", err.msg)
            @test occursin("6 parameters", err.msg)
        end
    end

    @testset "check_argument_count path not found" begin
        @test_throws ArgumentError check_argument_count("nonexistent_path_xyz")
    end

    @testset "check_argument_count on module" begin
        v = check_argument_count(
            CodeComplexity;
            max_args = 30,
            throw_on_violation = false,
        )
        @test v isa Vector{FileArguments}
    end
end
