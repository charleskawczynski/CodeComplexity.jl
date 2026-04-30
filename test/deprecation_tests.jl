# Smoke tests for the v1 (pre-singleton) and v2 (`*_complexity`)
# deprecation shims in `src/deprecated.jl`. Each shim emits a
# `Base.depwarn` and forwards into the v3 API; we only assert that the
# forwarding behaviour is correct. The depwarn output is expected and
# only prints when Julia is run with `--depwarn=yes` (Pkg.test's default).

@testset "Deprecations: v2 *_complexity shims" begin
    code = """
    function bad(a, b, c)
        if a > 0
            if b > 0
                if c > 0
                    return 1
                end
            end
        end
    end
    function ok(x)
        return x + 1
    end
    """

    @test CC.metric_complexity(CC.CyclomaticComplexity(), code) == 4
    @test CC.metric_complexity(CC.CognitiveComplexity(), code) == 6

    r = CC.complexity_report(CC.CyclomaticComplexity(), code)
    @test length(r) == 2
    @test r isa Vector{<:CC.FunctionMeasure}

    mktempdir() do tmpdir
        path = joinpath(tmpdir, "f.jl")
        write(path, code)

        fm = CC.file_complexity(CC.CyclomaticComplexity(), path)
        @test fm isa CC.FileMeasure{CC.CyclomaticComplexity}
        @test length(fm.functions) == 2

        dr = CC.directory_complexity(CC.CyclomaticComplexity(), tmpdir)
        @test dr isa Vector{<:CC.FileMeasure}
        @test length(dr) == 1

        v = CC.check_complexity(
            CC.CyclomaticComplexity(),
            path;
            max_value = 1,
            throw_on_violation = false,
        )
        @test length(v) == 1
    end

    pkg = CC.package_complexity(CC.CyclomaticComplexity(), CC)
    @test pkg isa Vector{<:CC.FileMeasure}
    @test !isempty(pkg)
end

@testset "Deprecations: v1 cyclomatic shims" begin
    code = """
    function f(x)
        if x > 0
            return x
        end
        return 0
    end
    """

    @test CC.cyclomatic_complexity(code) == 2

    r = CC.complexity_report(code)
    @test length(r) == 1
    @test r[1].name == "f"
    @test r[1].complexity == 2
    @test r[1].value == 2

    r2 = CC.complexity_report(code; max_complexity = 10)
    @test isempty(r2)

    mktempdir() do tmpdir
        path = joinpath(tmpdir, "g.jl")
        write(path, code)
        fm = CC.file_complexity(path)
        @test fm.total_complexity == 2
        @test fm.total_value == 2

        dr = CC.directory_complexity(tmpdir)
        @test length(dr) == 1

        @test isempty(CC.check_complexity(path; max_complexity = 5))
    end
end

@testset "Deprecations: v1 cognitive shims" begin
    code = """
    function f(x)
        if x > 0
            if x > 1
                return x
            end
        end
    end
    """

    @test CC.cognitive_complexity(code) == 3

    r = CC.cognitive_complexity_report(code)
    @test length(r) == 1
    @test r[1].complexity == 3
    @test r[1].value == 3

    mktempdir() do tmpdir
        path = joinpath(tmpdir, "c.jl")
        write(path, code)
        fm = CC.file_cognitive_complexity(path)
        @test fm.total_complexity == 3

        dr = CC.directory_cognitive_complexity(tmpdir)
        @test length(dr) == 1

        v = CC.check_cognitive_complexity(
            path;
            max_complexity = 1,
            throw_on_violation = false,
        )
        @test length(v) == 1
    end

    pkg = CC.package_cognitive_complexity(CC; max_complexity = 50)
    @test pkg isa Vector{<:CC.FileMeasure}
end

@testset "Deprecations: v1 argument-count shims" begin
    code = """
    function many(a, b, c, d, e, f) end
    function few(x) end
    """

    r = CC.argument_count_report(code)
    @test length(r) == 2
    byname = Dict(f.name => f.arg_count for f in r)
    @test byname["many"] == 6
    @test byname["few"] == 1

    r2 = CC.argument_count_report(code; max_args = 5, ignore = [:few])
    @test length(r2) == 1
    @test r2[1].name == "many"

    mktempdir() do tmpdir
        path = joinpath(tmpdir, "a.jl")
        write(path, code)
        fa = CC.file_argument_counts(path)
        @test fa isa CC.FileArguments
        @test fa.total_arguments == 7

        dr = CC.directory_argument_counts(tmpdir)
        @test length(dr) == 1

        @test_throws ErrorException CC.check_argument_count(path; max_args = 5)
        v = CC.check_argument_count(
            path;
            max_args = 5,
            throw_on_violation = false,
        )
        @test length(v) == 1
    end
end

@testset "Deprecations: type aliases" begin
    @test CC.FunctionComplexity === CC.FunctionMeasure
    @test CC.FileComplexity === CC.FileMeasure
    @test CC.FunctionCognitiveComplexity === CC.FunctionMeasure{CC.CognitiveComplexity}
    @test CC.FileCognitiveComplexity === CC.FileMeasure{CC.CognitiveComplexity}
    @test CC.FunctionArguments === CC.FunctionMeasure{CC.ArgumentCountComplexity}
    @test CC.FileArguments === CC.FileMeasure{CC.ArgumentCountComplexity}

    # Historical default constructor — `FunctionComplexity(name, value, line)`
    # produces a cyclomatic-keyed `FunctionMeasure` for source compatibility.
    fc = CC.FunctionComplexity("foo", 3, 7)
    @test fc isa CC.FunctionMeasure{CC.CyclomaticComplexity}
    @test fc.complexity == 3
    @test fc.value == 3
end
