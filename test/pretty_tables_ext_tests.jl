# Included from runtests.jl. Exercises the PrettyTables package extension
# that supplies methods for `CodeComplexity.measure_table`. Tests are
# written so that they only run on Julia versions that support package
# extensions (>= 1.9), which is also the package's declared compat.

using PrettyTables

@testset "measure_table (PrettyTables extension)" begin
    code = """
    function highc(x, y)
        if x > 0
            return x + y
        end
        return y
    end

    function lowc(a, b)
        return a + b
    end
    """

    metric = CC.CyclomaticComplexity()
    fns = CC.measure_report(metric, code)
    @test length(fns) == 2

    # Vector{FunctionMeasure}.
    buf = IOBuffer()
    CC.measure_table(buf, fns)
    out = String(take!(buf))
    @test occursin("function", out)
    @test occursin("Cyclomatic complexity", out)
    @test occursin("highc", out)
    @test occursin("lowc", out)

    # FileMeasure.
    fm = CC.FileMeasure("dummy_path.jl", fns)
    buf = IOBuffer()
    CC.measure_table(buf, fm)
    out = String(take!(buf))
    @test occursin("dummy_path.jl", out)
    @test occursin("Cyclomatic complexity", out)

    # Vector{FileMeasure}.
    fm2 = CC.FileMeasure("other.jl", fns)
    buf = IOBuffer()
    CC.measure_table(buf, [fm, fm2])
    out = String(take!(buf))
    @test occursin("dummy_path.jl", out)
    @test occursin("other.jl", out)

    # Single FunctionMeasure.
    buf = IOBuffer()
    CC.measure_table(buf, fns[1])
    out = String(take!(buf))
    @test occursin(fns[1].name, out)

    # Empty vectors render an empty table without erroring.
    empty_fns = CC.FunctionMeasure{CC.CyclomaticComplexity}[]
    buf = IOBuffer()
    CC.measure_table(buf, empty_fns)
    @test occursin("Cyclomatic complexity", String(take!(buf)))

    # kwargs are forwarded to PrettyTables (markdown backend produces
    # pipe-delimited output).
    buf = IOBuffer()
    CC.measure_table(buf, fns; backend = :markdown)
    @test occursin("|", String(take!(buf)))

    # Sorting: higher-complexity definitions appear before lower ones by
    # default; `highc` (cyclomatic = 2) should precede `lowc` (= 1).
    buf = IOBuffer()
    CC.measure_table(buf, fns)
    out = String(take!(buf))
    @test findfirst("highc", out).start < findfirst("lowc", out).start

    # sort_by_value = false preserves input order.
    buf = IOBuffer()
    CC.measure_table(buf, reverse(fns); sort_by_value = false)
    out = String(take!(buf))
    @test findfirst("lowc", out).start < findfirst("highc", out).start

    # rev = false sorts ascending.
    buf = IOBuffer()
    CC.measure_table(buf, fns; rev = false)
    out = String(take!(buf))
    @test findfirst("lowc", out).start < findfirst("highc", out).start
end
