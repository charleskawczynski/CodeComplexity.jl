# Included from runtests.jl — cyclomatic-complexity correctness tests
# exercised through the v3 API: `CC.measure_code(CC.CyclomaticComplexity(), …)`,
# `CC.measure_report(CC.CyclomaticComplexity(), …)`, etc.

const CYCLO = CC.CyclomaticComplexity()
cyclo_measure(x) = CC.measure_code(CYCLO, x)

@testset "Cyclomatic: trivial cases" begin
    @testset "trivial function" begin
        code = """
        function trivial()
            return nothing
        end
        """
        @test cyclo_measure(code) == 1
    end

    @testset "expression as statement" begin
        code = """
        function expr_as_statement()
            0xF00D
        end
        """
        @test cyclo_measure(code) == 1
    end

    @testset "sequential statements" begin
        code = """
        function sequential(n)
            k = n + 4
            s = k + n
            return s
        end
        """
        @test cyclo_measure(code) == 1
    end

    @testset "short form function" begin
        code = "f(x) = x + 1"
        @test cyclo_measure(code) == 1
    end
end

@testset "Cyclomatic: if statements" begin
    @testset "simple if" begin
        code = """
        function simple_if(x)
            if x > 0
                return x
            end
            return 0
        end
        """
        @test cyclo_measure(code) == 2
    end

    @testset "if-else" begin
        code = """
        function if_else(x)
            if x > 0
                return x
            else
                return -x
            end
        end
        """
        @test cyclo_measure(code) == 2
    end

    @testset "if-elseif-else" begin
        code = """
        function if_elseif_else(n)
            if n > 3
                return "bigger than three"
            elseif n > 4
                return "is never executed"
            else
                return "smaller than or equal to three"
            end
        end
        """
        @test cyclo_measure(code) == 3
    end

    @testset "nested ifs" begin
        code = """
        function nested_ifs(n)
            if n > 3
                if n > 4
                    return "bigger than four"
                else
                    return "bigger than three"
                end
            else
                return "smaller than or equal to three"
            end
        end
        """
        @test cyclo_measure(code) == 3
    end

    @testset "multiple elseif" begin
        code = """
        function multiple_elseif(x)
            if x == 1
                return "one"
            elseif x == 2
                return "two"
            elseif x == 3
                return "three"
            elseif x == 4
                return "four"
            else
                return "other"
            end
        end
        """
        @test cyclo_measure(code) == 5
    end
end

@testset "Cyclomatic: loops" begin
    @testset "for loop" begin
        code = """
        function for_loop()
            for i in 1:10
                println(i)
            end
        end
        """
        @test cyclo_measure(code) == 2
    end

    @testset "nested for loops" begin
        code = """
        function nested_for()
            for i in 1:10
                for j in 1:10
                    println(i * j)
                end
            end
        end
        """
        @test cyclo_measure(code) == 3
    end

    @testset "while loop" begin
        code = """
        function while_loop(n)
            while n > 0
                n -= 1
            end
            return n
        end
        """
        @test cyclo_measure(code) == 2
    end

    @testset "for with if" begin
        code = """
        function for_with_if(items)
            for item in items
                if item > 0
                    println(item)
                end
            end
        end
        """
        @test cyclo_measure(code) == 3
    end
end

@testset "Cyclomatic: short-circuit operators" begin
    @testset "single &&" begin
        code = """
        function and_operator(a, b)
            return a && b
        end
        """
        @test cyclo_measure(code) == 2
    end

    @testset "single ||" begin
        code = """
        function or_operator(a, b)
            return a || b
        end
        """
        @test cyclo_measure(code) == 2
    end

    @testset "chained &&" begin
        code = """
        function chained_and(a, b, c)
            return a && b && c
        end
        """
        @test cyclo_measure(code) == 3
    end

    @testset "mixed && and ||" begin
        code = """
        function mixed_operators(a, b, c)
            return a && b || c
        end
        """
        @test cyclo_measure(code) == 3
    end

    @testset "&& as control flow" begin
        code = """
        function and_control_flow(x)
            x > 0 && return x
            return 0
        end
        """
        @test cyclo_measure(code) == 2
    end

    @testset "|| as control flow" begin
        code = """
        function or_control_flow(x)
            x <= 0 || return x
            return 0
        end
        """
        @test cyclo_measure(code) == 2
    end
end

@testset "Cyclomatic: ternary operator" begin
    @testset "simple ternary" begin
        code = """
        function simple_ternary(x)
            return x > 0 ? x : -x
        end
        """
        @test cyclo_measure(code) == 2
    end

    @testset "nested ternary" begin
        code = """
        function nested_ternary(x)
            return x > 0 ? (x > 10 ? "big" : "small") : "negative"
        end
        """
        @test cyclo_measure(code) == 3
    end
end

@testset "Cyclomatic: try-catch" begin
    @testset "simple try-catch" begin
        code = """
        function simple_try()
            try
                risky_operation()
            catch
                handle_error()
            end
        end
        """
        @test cyclo_measure(code) == 2
    end

    @testset "try-catch-finally" begin
        code = """
        function try_catch_finally()
            try
                risky_operation()
            catch e
                handle_error(e)
            finally
                cleanup()
            end
        end
        """
        @test cyclo_measure(code) == 2
    end

    @testset "try-finally (no catch)" begin
        code = """
        function try_finally()
            try
                risky_operation()
            finally
                cleanup()
            end
        end
        """
        @test cyclo_measure(code) == 1
    end

    @testset "nested try-catch" begin
        code = """
        function nested_try()
            try
                try
                    inner_risky()
                catch
                    handle_inner()
                end
            catch
                handle_outer()
            end
        end
        """
        @test cyclo_measure(code) == 3
    end

    @testset "try with if in catch" begin
        code = """
        function try_with_if_in_catch()
            try
                risky()
            catch e
                if e isa IOError
                    handle_io()
                end
            end
        end
        """
        @test cyclo_measure(code) == 3
    end
end

@testset "Cyclomatic: nested functions" begin
    @testset "inner function" begin
        code = """
        function outer()
            function inner()
                return 1
            end
            return inner()
        end
        """
        @test cyclo_measure(code) == 1
    end

    @testset "inner function with if" begin
        code = """
        function outer(x)
            function inner(y)
                if y > 0
                    return y
                end
                return 0
            end
            return inner(x)
        end
        """
        @test cyclo_measure(code) == 2
    end
end

@testset "Cyclomatic: complex examples" begin
    @testset "recursive function" begin
        code = """
        function factorial(n)
            if n <= 1
                return 1
            else
                return n * factorial(n - 1)
            end
        end
        """
        @test cyclo_measure(code) == 2
    end

    @testset "binary search" begin
        code = """
        function binary_search(arr, target)
            low = 1
            high = length(arr)
            while low <= high
                mid = (low + high) ÷ 2
                if arr[mid] == target
                    return mid
                elseif arr[mid] < target
                    low = mid + 1
                else
                    high = mid - 1
                end
            end
            return -1
        end
        """
        @test cyclo_measure(code) == 4
    end

    @testset "fizzbuzz" begin
        code = """
        function fizzbuzz(n)
            for i in 1:n
                if i % 15 == 0
                    println("FizzBuzz")
                elseif i % 3 == 0
                    println("Fizz")
                elseif i % 5 == 0
                    println("Buzz")
                else
                    println(i)
                end
            end
        end
        """
        @test cyclo_measure(code) == 5
    end

    @testset "quicksort partition" begin
        code = """
        function partition!(arr, low, high)
            pivot = arr[high]
            i = low - 1
            for j in low:high-1
                if arr[j] <= pivot
                    i += 1
                    arr[i], arr[j] = arr[j], arr[i]
                end
            end
            arr[i+1], arr[high] = arr[high], arr[i+1]
            return i + 1
        end
        """
        @test cyclo_measure(code) == 3
    end
end

@testset "Cyclomatic: measure_report" begin
    @testset "single function" begin
        code = """
        function foo(x)
            if x > 0
                return x
            end
            return 0
        end
        """
        report = CC.measure_report(CYCLO, code)
        @test length(report) == 1
        @test report[1].name == "foo"
        @test report[1].value == 2
    end

    @testset "multiple functions" begin
        code = """
        function foo(x)
            return x + 1
        end

        function bar(x, y)
            if x > y
                return x
            else
                return y
            end
        end

        function baz(items)
            total = 0
            for item in items
                if item > 0
                    total += item
                end
            end
            return total
        end
        """
        report = CC.measure_report(CYCLO, code)
        @test length(report) == 3

        foo_report = filter(r -> r.name == "foo", report)[1]
        bar_report = filter(r -> r.name == "bar", report)[1]
        baz_report = filter(r -> r.name == "baz", report)[1]

        @test foo_report.value == 1
        @test bar_report.value == 2
        @test baz_report.value == 3
    end

    @testset "short form functions" begin
        code = """
        square(x) = x * x

        function cube(x)
            return x * x * x
        end

        abs_val(x) = x >= 0 ? x : -x
        """
        report = CC.measure_report(CYCLO, code)
        @test length(report) == 3

        square_report = filter(r -> r.name == "square", report)[1]
        cube_report = filter(r -> r.name == "cube", report)[1]
        abs_report = filter(r -> r.name == "abs_val", report)[1]

        @test square_report.value == 1
        @test cube_report.value == 1
        @test abs_report.value == 2
    end

    @testset "parametric functions" begin
        code = """
        function typed_func(x::Int)
            if x > 0
                return x
            end
            return 0
        end

        function generic_func(x::T) where T <: Number
            if x > zero(T)
                return x
            end
            return zero(T)
        end
        """
        report = CC.measure_report(CYCLO, code)
        @test length(report) == 2

        typed_report = filter(r -> r.name == "typed_func", report)[1]
        generic_report = filter(r -> r.name == "generic_func", report)[1]

        @test typed_report.value == 2
        @test generic_report.value == 2
    end
end

@testset "Cyclomatic: file and directory analysis" begin
    mktempdir() do tmpdir
        file1 = joinpath(tmpdir, "file1.jl")
        write(
            file1,
            """
function simple()
    return 1
end

function with_if(x)
    if x > 0
        return x
    end
    return 0
end
""",
        )

        subdir = joinpath(tmpdir, "subdir")
        mkdir(subdir)
        file2 = joinpath(subdir, "file2.jl")
        write(
            file2,
            """
function complex_func(x, y)
    if x > 0
        if y > 0
            return x + y
        else
            return x - y
        end
    else
        return 0
    end
end
""",
        )

        @testset "measure_file" begin
            fc = CC.measure_file(CYCLO, file1)
            @test fc.path == file1
            @test length(fc.functions) == 2
            @test fc.total_value == 3  # 1 + 2
        end

        @testset "measure_directory recursive" begin
            results = CC.measure_directory(CYCLO, tmpdir; recursive = true)
            @test length(results) == 2

            total_funcs = sum(length(fc.functions) for fc in results)
            @test total_funcs == 3
        end

        @testset "measure_directory non-recursive" begin
            results = CC.measure_directory(CYCLO, tmpdir; recursive = false)
            @test length(results) == 1
            @test results[1].path == file1
        end

        @testset "file not found" begin
            @test_throws ArgumentError CC.measure_file(CYCLO, "nonexistent.jl")
        end

        @testset "directory not found" begin
            @test_throws ArgumentError CC.measure_directory(CYCLO, "nonexistent_dir")
        end
    end
end

@testset "Cyclomatic: edge cases" begin
    @testset "empty function" begin
        code = """
        function empty_func()
        end
        """
        @test cyclo_measure(code) == 1
    end

    @testset "function with only comments" begin
        code = """
        function commented()
            # This is a comment
            # Another comment
        end
        """
        @test cyclo_measure(code) == 1
    end

    @testset "anonymous function" begin
        code = "x -> x + 1"
        @test cyclo_measure(code) == 1
    end

    @testset "anonymous function with if" begin
        code = "x -> x > 0 ? x : -x"
        @test cyclo_measure(code) == 2
    end

    @testset "do block" begin
        code = """
        function with_do()
            map([1,2,3]) do x
                if x > 1
                    return x * 2
                end
                return x
            end
        end
        """
        @test cyclo_measure(code) == 2
    end

    @testset "generator expression" begin
        code = """
        function with_generator()
            return sum(x for x in 1:10 if x % 2 == 0)
        end
        """
        @test cyclo_measure(code) >= 1
    end

    @testset "comprehension with condition" begin
        code = """
        function with_comprehension()
            return [x^2 for x in 1:10 if x % 2 == 0]
        end
        """
        @test cyclo_measure(code) >= 1
    end
end

@testset "Cyclomatic: macro definitions" begin
    @testset "simple macro" begin
        code = """
        macro simple_macro(x)
            return x
        end
        """
        report = CC.measure_report(CYCLO, code)
        @test length(report) == 1
        @test report[1].name == "@simple_macro"
        @test report[1].value == 1
    end

    @testset "macro with if" begin
        code = """
        macro conditional_macro(x)
            if x isa Symbol
                return x
            else
                return :(nothing)
            end
        end
        """
        report = CC.measure_report(CYCLO, code)
        @test length(report) == 1
        @test report[1].name == "@conditional_macro"
        @test report[1].value == 2
    end
end

@testset "Cyclomatic: FunctionMeasure / FileMeasure structs" begin
    fc = CC.FunctionMeasure{CC.CyclomaticComplexity}("test_func", 5, 10)
    @test fc.name == "test_func"
    @test fc.value == 5
    @test fc.line == 10

    io = IOBuffer()
    show(io, fc)
    output = String(take!(io))
    @test occursin("test_func", output)
    @test occursin("5", output)

    funcs = [
        CC.FunctionMeasure{CC.CyclomaticComplexity}("foo", 2, 1),
        CC.FunctionMeasure{CC.CyclomaticComplexity}("bar", 3, 10),
    ]
    fl = CC.FileMeasure("test.jl", funcs)
    @test fl.path == "test.jl"
    @test length(fl.functions) == 2
    @test fl.total_value == 5
end

@testset "Cyclomatic: max_value filtering" begin
    @testset "measure_report with max_value" begin
        code = """
        function simple()
            return 1
        end

        function medium(x)
            if x > 0
                return x
            end
            return 0
        end

        function complex(x, y, z)
            if x > 0
                if y > 0
                    if z > 0
                        return x + y + z
                    else
                        return x + y
                    end
                else
                    return x
                end
            else
                return 0
            end
        end
        """
        all_report = CC.measure_report(CYCLO, code)
        @test length(all_report) == 3

        filtered = CC.measure_report(CYCLO, code; max_value = 1)
        @test length(filtered) == 2
        @test all(f -> f.value > 1, filtered)

        filtered = CC.measure_report(CYCLO, code; max_value = 2)
        @test length(filtered) == 1
        @test filtered[1].name == "complex"
        @test filtered[1].value == 4

        filtered = CC.measure_report(CYCLO, code; max_value = 10)
        @test isempty(filtered)
    end

    @testset "measure_file with max_value" begin
        mktempdir() do tmpdir
            file = joinpath(tmpdir, "test.jl")
            write(
                file,
                """
    function low()
        return 1
    end

    function high(x, y)
        if x > 0
            if y > 0
                return x + y
            end
        end
        return 0
    end
    """,
            )

            fc = CC.measure_file(CYCLO, file)
            @test length(fc.functions) == 2
            @test fc.total_value == 4

            fc = CC.measure_file(CYCLO, file; max_value = 1)
            @test length(fc.functions) == 1
            @test fc.functions[1].name == "high"
            @test fc.total_value == 3
        end
    end

    @testset "measure_directory with max_value" begin
        mktempdir() do tmpdir
            file1 = joinpath(tmpdir, "simple.jl")
            write(
                file1,
                """
   function a()
       return 1
   end
   function b()
       return 2
   end
   """,
            )

            file2 = joinpath(tmpdir, "mixed.jl")
            write(
                file2,
                """
   function c()
       return 3
   end
   function d(x, y, z)
       if x > 0
           if y > 0
               if z > 0
                   return 1
               end
           end
       end
       return 0
   end
   """,
            )

            results = CC.measure_directory(CYCLO, tmpdir)
            @test length(results) == 2

            results = CC.measure_directory(CYCLO, tmpdir; max_value = 2)
            @test length(results) == 1
            @test basename(results[1].path) == "mixed.jl"
            @test length(results[1].functions) == 1
            @test results[1].functions[1].name == "d"

            results = CC.measure_directory(CYCLO, tmpdir; max_value = 10)
            @test isempty(results)
        end
    end
end

@testset "Cyclomatic: check_measure" begin
    @testset "no violations" begin
        mktempdir() do tmpdir
            file = joinpath(tmpdir, "good.jl")
            write(
                file,
                """
    function simple()
        return 1
    end
    """,
            )
            violations = CC.check_measure(CYCLO, file; max_value = 5)
            @test isempty(violations)
        end
    end

    @testset "with violations" begin
        mktempdir() do tmpdir
            file = joinpath(tmpdir, "bad.jl")
            write(
                file,
                """
    function complex(a, b, c, d)
        if a > 0
            if b > 0
                if c > 0
                    if d > 0
                        return 1
                    end
                end
            end
        end
        return 0
    end
    """,
            )

            @test_throws ErrorException CC.check_measure(CYCLO, file; max_value = 3)

            violations = CC.check_measure(
                CYCLO,
                file;
                max_value = 3,
                throw_on_violation = false,
            )
            @test length(violations) == 1
            @test violations[1].functions[1].name == "complex"
            @test violations[1].functions[1].value == 5
        end
    end

    @testset "directory" begin
        mktempdir() do tmpdir
            write(
                joinpath(tmpdir, "good.jl"),
                """
function ok()
    return 1
end
""",
            )

            write(
                joinpath(tmpdir, "bad.jl"),
                """
function too_complex(x, y)
    if x > 0
        if y > 0
            return x + y
        end
    end
    return 0
end
""",
            )

            @test_throws ErrorException CC.check_measure(CYCLO, tmpdir; max_value = 2)

            violations = CC.check_measure(
                CYCLO,
                tmpdir;
                max_value = 2,
                throw_on_violation = false,
            )
            @test length(violations) == 1
            @test occursin("bad.jl", violations[1].path)
        end
    end

    @testset "module" begin
        violations = CC.check_measure(
            CYCLO,
            CC;
            max_value = 20,
            throw_on_violation = false,
        )
        @test violations isa Vector{<:CC.FileMeasure}
    end

    @testset "error message format" begin
        mktempdir() do tmpdir
            file = joinpath(tmpdir, "test.jl")
            write(
                file,
                """
    function problematic(x)
        if x > 0
            if x > 1
                return 2
            end
        end
        return 0
    end
    """,
            )

            err = try
                CC.check_measure(CYCLO, file; max_value = 2)
                nothing
            catch e
                e
            end

            @test err !== nothing
            @test occursin("Cyclomatic complexity violations", err.msg)
            @test occursin("problematic", err.msg)
            @test occursin("complexity 3", err.msg)
        end
    end

    @testset "default max_value" begin
        mktempdir() do tmpdir
            file = joinpath(tmpdir, "simple.jl")
            write(
                file,
                """
    function simple()
        return 1
    end
    """,
            )

            violations = CC.check_measure(CYCLO, file)
            @test isempty(violations)
        end
    end

    @testset "path not found" begin
        @test_throws ArgumentError CC.check_measure(CYCLO, "nonexistent_path")
    end
end
