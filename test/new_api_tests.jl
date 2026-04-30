# Included from runtests.jl. Exercises the unified singleton-pattern API
# (measure / measure_report / measure_file / measure_directory /
# measure_package / check_measure dispatched on an `AbstractMetric` first
# argument) through the qualified `CC.` form.

const ALL_METRICS = (
    CC.CyclomaticComplexity(),
    CC.CognitiveComplexity(),
    CC.ArgumentCountComplexity(),
)

@testset "metric singletons" begin
    for metric in ALL_METRICS
        @test metric isa CC.AbstractMetric
        @test CC.metric_label(metric) isa String
        @test CC.default_max_value(metric) isa Int
    end

    @test CC.default_max_value(CC.CyclomaticComplexity()) == 10
    @test CC.default_max_value(CC.CognitiveComplexity()) == 15
    @test CC.default_max_value(CC.ArgumentCountComplexity()) == 5
end

@testset "measure_code dispatch" begin
    code = """
    function f(x, y)
        if x > 0
            return x + y
        end
        return y
    end
    """
    @test CC.measure_code(CC.CyclomaticComplexity(), code) == 2
    @test CC.measure_code(CC.CognitiveComplexity(), code) == 1

    expr = Meta.parse("function g(a, b, c, d); return a; end")
    @test CC.measure_code(CC.ArgumentCountComplexity(), expr) == 4
    @test CC.measure_code(CC.ArgumentCountComplexity(), :((a, b, c)::Foo)) == 0
    @test CC.measure_code(CC.ArgumentCountComplexity(), Meta.parse("h(a, b) = a + b")) == 2
    @test CC.measure_code(CC.ArgumentCountComplexity(), Meta.parse("(a, b) -> a + b")) == 2
end

@testset "measure_report parametric return type" begin
    code = "f(x) = x + 1"
    for metric in ALL_METRICS
        report = CC.measure_report(metric, code)
        @test report isa Vector{CC.FunctionMeasure{typeof(metric)}}
        @test length(report) == 1
        @test report[1].name == "f"
    end
end

@testset "measure_file dispatch" begin
    mktempdir() do tmpdir
        path = joinpath(tmpdir, "f.jl")
        write(
            path,
            """
function ok(x, y)
    return x + y
end
function bad(a, b, c, d, e, f)
    if a > 0
        if b > 0
            return c
        end
    end
    return 0
end
""",
        )

        for metric in ALL_METRICS
            fc = CC.measure_file(metric, path)
            @test fc isa CC.FileMeasure{typeof(metric)}
            @test fc.path == path
            @test length(fc.functions) == 2
            @test fc.total_value >= 0
        end

        cyclo = CC.measure_file(CC.CyclomaticComplexity(), path; max_value = 1)
        @test all(f -> f.value > 1, cyclo.functions)

        argc = CC.measure_file(CC.ArgumentCountComplexity(), path; max_value = 5)
        @test length(argc.functions) == 1
        @test argc.functions[1].name == "bad"
    end
end

@testset "measure_directory dispatch" begin
    mktempdir() do tmpdir
        write(
            joinpath(tmpdir, "a.jl"),
            "function a(); return 1; end\nfunction b(x, y, z, w, p, q); return x; end\n",
        )
        write(
            joinpath(tmpdir, "b.jl"),
            "function c(x); if x > 0; return x; else; return 0; end; end\n",
        )

        for metric in ALL_METRICS
            results = CC.measure_directory(metric, tmpdir)
            @test results isa Vector{CC.FileMeasure{typeof(metric)}}
            @test length(results) == 2
        end

        violators = CC.measure_directory(
            CC.ArgumentCountComplexity(),
            tmpdir;
            max_value = 5,
        )
        @test length(violators) == 1
        @test occursin("a.jl", violators[1].path)
    end
end

@testset "check_measure dispatch" begin
    mktempdir() do tmpdir
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
end
""",
        )

        for metric in (CC.CyclomaticComplexity(), CC.CognitiveComplexity())
            @test_throws ErrorException CC.check_measure(
                metric,
                bad;
                max_value = 1,
            )
            v = CC.check_measure(
                metric,
                bad;
                max_value = 1,
                throw_on_violation = false,
            )
            @test length(v) == 1
        end

        @test_throws ErrorException CC.check_measure(
            CC.ArgumentCountComplexity(),
            bad;
            max_value = 2,
        )
        ok = CC.check_measure(
            CC.ArgumentCountComplexity(),
            bad;
            max_value = 5,
            throw_on_violation = false,
        )
        @test isempty(ok)

        # default_max_value used when no kwarg
        @test isempty(
            CC.check_measure(
                CC.CyclomaticComplexity(),
                bad;
                throw_on_violation = false,
            ),
        )
    end
end

@testset "ArgumentCountComplexity ignore kwarg" begin
    code = """
    function many(a, b, c, d, e, f) end
    function few(a) end
    """
    fns = CC.measure_report(
        CC.ArgumentCountComplexity(),
        code;
        ignore = [:many],
    )
    @test length(fns) == 1
    @test fns[1].name == "few"

    fns2 = CC.measure_report(
        CC.ArgumentCountComplexity(),
        code;
        max_value = 5,
        ignore = (:many,),
    )
    @test isempty(fns2)
end

@testset "measure_package on this package" begin
    for metric in ALL_METRICS
        results = CC.measure_package(metric, CC)
        @test results isa Vector{CC.FileMeasure{typeof(metric)}}
        @test !isempty(results)
    end
end

@testset "FunctionMeasure / FileMeasure parametric construction" begin
    fns = [
        CC.FunctionMeasure{CC.CognitiveComplexity}("a", 2, 1),
        CC.FunctionMeasure{CC.CognitiveComplexity}("b", 5, 9),
    ]
    fc = CC.FileMeasure("x.jl", fns)
    @test fc isa CC.FileMeasure{CC.CognitiveComplexity}
    @test fc.total_value == 7
    @test fc.functions[1].value == 2
end
