# Included from runtests.jl — cognitive complexity metric, reports, and check_cognitive_complexity.

@testset "Cognitive: trivial cases" begin
    @testset "trivial function" begin
        code = """
        function trivial()
            return nothing
        end
        """
        @test cognitive_complexity(code) == 0
    end

    @testset "sequential statements" begin
        code = """
        function sequential(n)
            k = n + 4
            s = k + n
            return s
        end
        """
        @test cognitive_complexity(code) == 0
    end

    @testset "short form function" begin
        @test cognitive_complexity("f(x) = x + 1") == 0
    end
end

@testset "Cognitive: if/elseif/else" begin
    @testset "simple if" begin
        code = """
        function f(x)
            if x > 0
                return x
            end
        end
        """
        @test cognitive_complexity(code) == 1
    end

    @testset "if-else (+1 hybrid for else)" begin
        code = """
        function f(x)
            if x > 0
                return x
            else
                return -x
            end
        end
        """
        @test cognitive_complexity(code) == 2
    end

    @testset "if-elseif (+1 each)" begin
        code = """
        function f(x)
            if x > 0
                return 1
            elseif x < 0
                return -1
            end
        end
        """
        @test cognitive_complexity(code) == 2
    end

    @testset "if-elseif-else" begin
        code = """
        function f(x)
            if x == 1
                return "one"
            elseif x == 2
                return "two"
            else
                return "other"
            end
        end
        """
        @test cognitive_complexity(code) == 3
    end

    @testset "nested if (nesting increment)" begin
        code = """
        function f(x, y)
            if x > 0
                if y > 0
                    return x + y
                end
            end
        end
        """
        # outer if: +1, inner if: +1+1 nesting = +2 → total 3
        @test cognitive_complexity(code) == 3
    end

    @testset "deeply nested ifs" begin
        code = """
        function f(a, b, c)
            if a > 0
                if b > 0
                    if c > 0
                        return 1
                    end
                end
            end
        end
        """
        # +1, +2, +3 → 6
        @test cognitive_complexity(code) == 6
    end
end

@testset "Cognitive: loops" begin
    @testset "single for" begin
        code = """
        function f()
            for i in 1:10
                println(i)
            end
        end
        """
        @test cognitive_complexity(code) == 1
    end

    @testset "nested for" begin
        code = """
        function f()
            for i in 1:10
                for j in 1:10
                    println(i*j)
                end
            end
        end
        """
        # +1 + (+1+1) = 3
        @test cognitive_complexity(code) == 3
    end

    @testset "triple nested for" begin
        code = """
        function f()
            for i in 1:10
                for j in 1:10
                    for k in 1:10
                        println(i*j*k)
                    end
                end
            end
        end
        """
        # +1 + +2 + +3 = 6
        @test cognitive_complexity(code) == 6
    end

    @testset "while" begin
        code = """
        function f(n)
            while n > 0
                n -= 1
            end
        end
        """
        @test cognitive_complexity(code) == 1
    end

    @testset "for with if (nesting)" begin
        code = """
        function f(items)
            for item in items
                if item > 0
                    println(item)
                end
            end
        end
        """
        # +1 for + (+1+1 if nested) = 3
        @test cognitive_complexity(code) == 3
    end
end

@testset "Cognitive: short-circuit boolean sequences" begin
    @testset "single &&" begin
        @test cognitive_complexity("a && b") == 1
    end

    @testset "chained && counts as one sequence" begin
        @test cognitive_complexity("a && b && c") == 1
        @test cognitive_complexity("a && b && c && d") == 1
    end

    @testset "chained || counts as one sequence" begin
        @test cognitive_complexity("a || b || c || d") == 1
    end

    @testset "mixed && and || → two sequences" begin
        @test cognitive_complexity("a && b || c") == 2
        @test cognitive_complexity("a || b && c") == 2
    end

    @testset "negation does not collapse sequences" begin
        # Whitepaper example: a && !(b && c) → 2
        @test cognitive_complexity("a && !(b && c)") == 2
    end

    @testset "if with boolean condition" begin
        code = """
        function f(a, b, c)
            if a && b && c
                return 1
            end
        end
        """
        # +1 if + +1 single && sequence = 2
        @test cognitive_complexity(code) == 2
    end

    @testset "if with mixed boolean condition" begin
        code = """
        function f(a, b, c, d)
            if a && b || c && d
                return 1
            end
        end
        """
        # +1 if + sequences (||, &&, &&) = 1 + 3 = 4. Right-assoc: ||(&&(a,b), &&(c,d)) → top || (+1), each && (+1 each) = 3 sequences.
        @test cognitive_complexity(code) == 4
    end
end

@testset "Cognitive: ternary" begin
    @testset "simple ternary" begin
        # Note: Julia's parser converts `a ? b : c` to an `if … else … end` AST node,
        # so we report it as if/else (+1 if, +1 else) rather than the paper's
        # single-increment ternary rule.
        @test cognitive_complexity("x > 0 ? x : -x") == 2
    end

    @testset "nested ternary" begin
        # outer if/else: +2 (top-level), inner if/else inside else branch: +2 nested + +1 hybrid = 4? Let's compute:
        # outer if at 0: base = 1+0+1(else) = 2. then-branch nesting=1.
        # else-branch: nested ternary → if at nesting=1: base = 1+1+1(else)=3. → total 5.
        @test cognitive_complexity("x > 0 ? x : (y > 0 ? y : -y)") == 5
    end
end

@testset "Cognitive: try/catch" begin
    @testset "try without catch is free" begin
        code = """
        function f()
            try
                a()
            finally
                b()
            end
        end
        """
        @test cognitive_complexity(code) == 0
    end

    @testset "try with catch" begin
        code = """
        function f()
            try
                a()
            catch
                b()
            end
        end
        """
        @test cognitive_complexity(code) == 1
    end

    @testset "catch with nested if (whitepaper-style)" begin
        # void myMethod () { try { if (c1) { for { while {…} } } } catch { if (c2) … } }
        # → 1 + 2 + 3 + 1 + 2 = 9
        code = """
        function myMethod()
            try
                if condition1
                    for i in 1:10
                        while condition2
                            doit()
                        end
                    end
                end
            catch
                if condition2
                    handle()
                end
            end
        end
        """
        @test cognitive_complexity(code) == 9
    end
end

@testset "Cognitive: recursion" begin
    @testset "self-recursive function adds +1" begin
        code = """
        function fact(n)
            if n <= 1
                return 1
            else
                return n * fact(n - 1)
            end
        end
        """
        # if/else: 2; recursion: +1 → 3
        @test cognitive_complexity(code) == 3
    end

    @testset "non-recursive identical shape" begin
        code = """
        function abs_val(x)
            if x > 0
                return x
            else
                return -x
            end
        end
        """
        @test cognitive_complexity(code) == 2
    end

    @testset "short-form recursion" begin
        @test cognitive_complexity("f(n) = n <= 1 ? 1 : n * f(n - 1)") == 3
    end
end

@testset "Cognitive: @goto" begin
    code = """
    function loop()
        for i in 1:10
            for j in 1:10
                if i == j
                    @goto out
                end
            end
        end
        @label out
        return nothing
    end
    """
    # for(+1) + for(+2) + if(+3) + @goto(+1) = 7  (matches sumOfPrimes example from spec)
    @test cognitive_complexity(code) == 7
end

@testset "Cognitive: lambdas and nested functions" begin
    @testset "lambda inside function adds nesting" begin
        code = """
        function myMethod()
            r = () -> begin
                if condition1
                    something()
                end
            end
        end
        """
        # Lambda body if: +1 + 1 nesting = 2
        @test cognitive_complexity(code) == 2
    end

    @testset "top-level lambda body counted at nesting 0" begin
        @test cognitive_complexity("x -> x > 0 ? x : -x") == 2
    end

    @testset "nested function adds nesting" begin
        code = """
        function outer()
            function inner()
                if x
                end
            end
        end
        """
        @test cognitive_complexity(code) == 2
    end
end

@testset "cognitive_complexity_report" begin
    @testset "multiple functions" begin
        code = """
        function trivial()
            return 1
        end

        function with_if(x)
            if x > 0
                return x
            end
        end

        function with_loop_and_if(items)
            for item in items
                if item > 0
                    println(item)
                end
            end
        end
        """
        report = cognitive_complexity_report(code)
        @test length(report) == 3
        d = Dict(r.name => r.complexity for r in report)
        @test d["trivial"] == 0
        @test d["with_if"] == 1
        @test d["with_loop_and_if"] == 3
    end

    @testset "macro definitions" begin
        code = """
        macro simple(x)
            return x
        end

        macro with_if(x)
            if x isa Symbol
                return x
            else
                return :(nothing)
            end
        end
        """
        report = cognitive_complexity_report(code)
        @test length(report) == 2
        d = Dict(r.name => r.complexity for r in report)
        @test d["@simple"] == 0
        @test d["@with_if"] == 2
    end

    @testset "anonymous function" begin
        code = "f = x -> x > 0 ? x : -x"
        report = cognitive_complexity_report(code)
        @test length(report) == 1
        @test report[1].name == "<anonymous>"
        @test report[1].complexity == 2
    end

    @testset "max_complexity filter" begin
        code = """
        function low()
            return 1
        end

        function high(a, b, c)
            if a > 0
                if b > 0
                    if c > 0
                        return 1
                    end
                end
            end
        end
        """
        # high cognitive: 1+2+3 = 6
        all_report = cognitive_complexity_report(code)
        @test length(all_report) == 2

        filtered = cognitive_complexity_report(code; max_complexity = 3)
        @test length(filtered) == 1
        @test filtered[1].name == "high"
        @test filtered[1].complexity == 6

        @test isempty(cognitive_complexity_report(code; max_complexity = 100))
    end
end

@testset "FunctionCognitiveComplexity / FileCognitiveComplexity" begin
    f = FunctionCognitiveComplexity("foo", 7, 12)
    @test f.name == "foo"
    @test f.complexity == 7
    @test f.line == 12

    io = IOBuffer()
    show(io, f)
    out = String(take!(io))
    @test occursin("foo", out)
    @test occursin("7", out)

    fc = FileCognitiveComplexity(
        "x.jl",
        [
            FunctionCognitiveComplexity("a", 2, 1),
            FunctionCognitiveComplexity("b", 5, 10),
        ],
    )
    @test fc.path == "x.jl"
    @test fc.total_complexity == 7
end

@testset "file/directory/check cognitive_complexity" begin
    mktempdir() do tmpdir
        good = joinpath(tmpdir, "good.jl")
        write(
            good,
            """
function ok(x)
    return x + 1
end
""",
        )

        bad = joinpath(tmpdir, "bad.jl")
        write(
            bad,
            """
function nested(a, b, c)
    if a > 0
        if b > 0
            if c > 0
                return 1
            end
        end
    end
    return 0
end
""",
        )

        @testset "file_cognitive_complexity" begin
            fc = file_cognitive_complexity(good)
            @test fc.path == good
            @test length(fc.functions) == 1
            @test fc.functions[1].complexity == 0

            fc = file_cognitive_complexity(bad)
            @test length(fc.functions) == 1
            @test fc.functions[1].name == "nested"
            @test fc.functions[1].complexity == 6
            @test fc.total_complexity == 6
        end

        @testset "file_cognitive_complexity max_complexity" begin
            fc = file_cognitive_complexity(bad; max_complexity = 3)
            @test length(fc.functions) == 1

            fc = file_cognitive_complexity(bad; max_complexity = 100)
            @test isempty(fc.functions)
            @test fc.total_complexity == 0
        end

        @testset "file not found" begin
            @test_throws ArgumentError file_cognitive_complexity("nope.jl")
        end

        @testset "directory_cognitive_complexity" begin
            results = directory_cognitive_complexity(tmpdir)
            @test length(results) == 2

            results =
                directory_cognitive_complexity(tmpdir; max_complexity = 3)
            @test length(results) == 1
            @test occursin("bad.jl", results[1].path)

            @test_throws ArgumentError directory_cognitive_complexity("missing")
        end

        @testset "check_cognitive_complexity violates" begin
            @test_throws ErrorException check_cognitive_complexity(
                bad;
                max_complexity = 3,
            )
            v = check_cognitive_complexity(
                bad;
                max_complexity = 3,
                throw_on_violation = false,
            )
            @test length(v) == 1
        end

        @testset "check_cognitive_complexity ok" begin
            v = check_cognitive_complexity(good; max_complexity = 5)
            @test isempty(v)
        end

        @testset "check_cognitive_complexity directory" begin
            @test_throws ErrorException check_cognitive_complexity(
                tmpdir;
                max_complexity = 3,
            )
            v = check_cognitive_complexity(
                tmpdir;
                max_complexity = 3,
                throw_on_violation = false,
            )
            @test length(v) == 1
            @test occursin("bad.jl", v[1].path)
        end

        @testset "check_cognitive_complexity error message" begin
            err = try
                check_cognitive_complexity(bad; max_complexity = 3)
                nothing
            catch e
                e
            end
            @test err !== nothing
            @test occursin("Cognitive complexity violations", err.msg)
            @test occursin("nested", err.msg)
            @test occursin("complexity 6", err.msg)
        end

        @testset "check_cognitive_complexity path not found" begin
            @test_throws ArgumentError check_cognitive_complexity("nope_path")
        end
    end
end

@testset "package_cognitive_complexity" begin
    v = check_cognitive_complexity(
        CodeComplexity;
        max_complexity = 50,
        throw_on_violation = false,
    )
    @test v isa Vector{FileCognitiveComplexity}
end
