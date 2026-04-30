# Included from runtests.jl — PLR0913-style parameter counts and
# `check_measure` for `ArgumentCountComplexity`, exercised through the v3
# qualified API.

const ARGC = CC.ArgumentCountComplexity()
arg_measure(x) = CC.measure_code(ARGC, x)

@testset "Argument count (PLR0913-style)" begin
    @testset "measure_report counting" begin
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
        r = CC.measure_report(ARGC, code)
        byname = Dict(f.name => f.value for f in r)
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

    @testset "measure_report lambda lhs shapes" begin
        r = CC.measure_report(
            ARGC,
            "(t, u) -> t + u\nw -> w\ng(a, b) -> a\n(a, b; c = 1) -> a\n",
        )
        @test sort([x.value for x in r]) == [1, 2, 2, 3]
    end

    @testset "measure_report anonymous definitions" begin
        code = """
        (a, b) -> a + b
        x -> x
        """
        r = CC.measure_report(ARGC, code)
        @test length(r) == 2
        counts = sort([f.value for f in r])
        @test counts == [1, 2]
    end

    @testset "max_value filtering" begin
        code = "function many(a,b,c,d,e,f) end\nfunction few(a) end\n"
        allf = CC.measure_report(ARGC, code)
        @test length(allf) == 2
        viol = CC.measure_report(ARGC, code; max_value = 5)
        @test length(viol) == 1
        @test viol[1].name == "many"
        @test viol[1].value == 6
    end

    @testset "ignore list" begin
        code = """
        function many(a,b,c,d,e,f) end
        function few(a) end
        macro six(a,b,c,d,e,f) end
        """
        r = CC.measure_report(ARGC, code; ignore = [:many])
        @test length(r) == 2
        @test Set(f.name for f in r) == Set(["few", "@six"])
        @test !any(f -> f.name == "many", r)

        viol = CC.measure_report(ARGC, code; max_value = 5, ignore = [:many, "@six"])
        @test isempty(viol)

        viol2 = CC.measure_report(ARGC, code; max_value = 5, ignore = ["@six"])
        @test length(viol2) == 1
        @test viol2[1].name == "many"

        mktempdir() do tmpdir
            file = joinpath(tmpdir, "ig.jl")
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
            @test isempty(
                CC.check_measure(ARGC, file; max_value = 5, ignore = [:bad]),
            )
        end

        M = Module(:IgnoreCallableTest)
        Core.eval(
            M,
            quote
                struct IgCtor end
                function IgCtor(_a, _b, _c, _d, _e, _f)
                    IgCtor()
                end
                function ig_big(_a, _b, _c, _d, _e, _f)
                    nothing
                end
            end,
        )
        ig_big = getfield(M, :ig_big)
        IgCtor = getfield(M, :IgCtor)
        code_callable = """
        struct IgCtor end
        function IgCtor(_a, _b, _c, _d, _e, _f)
            IgCtor()
        end
        function ig_big(_a, _b, _c, _d, _e, _f)
            nothing
        end
        """
        viol_c = CC.measure_report(ARGC, code_callable; max_value = 5)
        @test length(viol_c) == 2
        @test Set(f.name for f in viol_c) == Set(["IgCtor", "ig_big"])

        @test isempty(
            CC.measure_report(
                ARGC,
                code_callable;
                max_value = 5,
                ignore = (ig_big, IgCtor),
            ),
        )
    end

    @testset "FunctionMeasure / FileMeasure aliases for ArgumentCountComplexity" begin
        fa = CC.FunctionMeasure{CC.ArgumentCountComplexity}("g", 7, 3)
        @test fa.name == "g" && fa.value == 7 && fa.line == 3
        fl = CC.FileMeasure{CC.ArgumentCountComplexity}(
            "x.jl",
            [
                CC.FunctionMeasure{CC.ArgumentCountComplexity}("g", 2, 1),
                CC.FunctionMeasure{CC.ArgumentCountComplexity}("h", 3, 2),
            ],
        )
        @test fl.path == "x.jl"
        @test fl.total_value == 5
    end

    @testset "measure_file and check_measure" begin
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
            fa = CC.measure_file(ARGC, file)
            @test length(fa.functions) == 2
            @test fa.total_value == 9

            fa_v = CC.measure_file(ARGC, file; max_value = 5)
            @test length(fa_v.functions) == 1
            @test fa_v.functions[1].name == "bad"

            @test_throws ErrorException CC.check_measure(ARGC, file; max_value = 5)
            v = CC.check_measure(
                ARGC,
                file;
                max_value = 5,
                throw_on_violation = false,
            )
            @test length(v) == 1
            @test v[1].functions[1].name == "bad"

            @test isempty(CC.check_measure(ARGC, file; max_value = 6))
        end
    end

    @testset "check_measure error message" begin
        mktempdir() do tmpdir
            file = joinpath(tmpdir, "t.jl")
            write(file, "function z(a,b,c,d,e,f) end\n")
            err = try
                CC.check_measure(ARGC, file; max_value = 5)
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

    @testset "check_measure path not found" begin
        @test_throws ArgumentError CC.check_measure(ARGC, "nonexistent_path_xyz")
    end

    @testset "check_measure on module" begin
        v = CC.check_measure(ARGC, CC; max_value = 30, throw_on_violation = false)
        @test v isa Vector{<:CC.FileMeasure}
    end
end
