# Included from runtests.jl — cyclomatic complexity metric, reports, and check_complexity.

@testset "Basic complexity" begin
    @testset "trivial function" begin
        code = """
        function trivial()
            return nothing
        end
        """
        @test cyclomatic_complexity(code) == 1
    end

    @testset "expression as statement" begin
        code = """
        function expr_as_statement()
            0xF00D
        end
        """
        @test cyclomatic_complexity(code) == 1
    end

    @testset "sequential statements" begin
        code = """
        function sequential(n)
            k = n + 4
            s = k + n
            return s
        end
        """
        @test cyclomatic_complexity(code) == 1
    end

    @testset "short form function" begin
        code = "f(x) = x + 1"
        @test cyclomatic_complexity(code) == 1
    end
end

@testset "If statements" begin
    @testset "simple if" begin
        code = """
        function simple_if(x)
            if x > 0
                return x
            end
            return 0
        end
        """
        @test cyclomatic_complexity(code) == 2
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
        @test cyclomatic_complexity(code) == 2
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
        @test cyclomatic_complexity(code) == 3
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
        @test cyclomatic_complexity(code) == 3
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
        @test cyclomatic_complexity(code) == 5
    end
end

@testset "Loops" begin
    @testset "for loop" begin
        code = """
        function for_loop()
            for i in 1:10
                println(i)
            end
        end
        """
        @test cyclomatic_complexity(code) == 2
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
        @test cyclomatic_complexity(code) == 3
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
        @test cyclomatic_complexity(code) == 2
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
        @test cyclomatic_complexity(code) == 3
    end
end

@testset "Short-circuit operators" begin
    @testset "single &&" begin
        code = """
        function and_operator(a, b)
            return a && b
        end
        """
        @test cyclomatic_complexity(code) == 2
    end

    @testset "single ||" begin
        code = """
        function or_operator(a, b)
            return a || b
        end
        """
        @test cyclomatic_complexity(code) == 2
    end

    @testset "chained &&" begin
        code = """
        function chained_and(a, b, c)
            return a && b && c
        end
        """
        @test cyclomatic_complexity(code) == 3
    end

    @testset "mixed && and ||" begin
        code = """
        function mixed_operators(a, b, c)
            return a && b || c
        end
        """
        @test cyclomatic_complexity(code) == 3
    end

    @testset "&& as control flow" begin
        code = """
        function and_control_flow(x)
            x > 0 && return x
            return 0
        end
        """
        @test cyclomatic_complexity(code) == 2
    end

    @testset "|| as control flow" begin
        code = """
        function or_control_flow(x)
            x <= 0 || return x
            return 0
        end
        """
        @test cyclomatic_complexity(code) == 2
    end
end

@testset "Ternary operator" begin
    @testset "simple ternary" begin
        code = """
        function simple_ternary(x)
            return x > 0 ? x : -x
        end
        """
        @test cyclomatic_complexity(code) == 2
    end

    @testset "nested ternary" begin
        code = """
        function nested_ternary(x)
            return x > 0 ? (x > 10 ? "big" : "small") : "negative"
        end
        """
        @test cyclomatic_complexity(code) == 3
    end
end

@testset "Try-catch" begin
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
        @test cyclomatic_complexity(code) == 2
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
        @test cyclomatic_complexity(code) == 2
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
        @test cyclomatic_complexity(code) == 1
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
        @test cyclomatic_complexity(code) == 3
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
        @test cyclomatic_complexity(code) == 3
    end
end

@testset "Nested functions" begin
    @testset "inner function" begin
        code = """
        function outer()
            function inner()
                return 1
            end
            return inner()
        end
        """
        # The inner function definition adds complexity
        @test cyclomatic_complexity(code) == 1
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
        @test cyclomatic_complexity(code) == 2
    end
end

@testset "Complex examples" begin
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
        @test cyclomatic_complexity(code) == 2
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
        @test cyclomatic_complexity(code) == 4
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
        @test cyclomatic_complexity(code) == 5
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
        @test cyclomatic_complexity(code) == 3
    end
end

@testset "complexity_report" begin
    @testset "single function" begin
        code = """
        function foo(x)
            if x > 0
                return x
            end
            return 0
        end
        """
        report = complexity_report(code)
        @test length(report) == 1
        @test report[1].name == "foo"
        @test report[1].complexity == 2
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
        report = complexity_report(code)
        @test length(report) == 3

        foo_report = filter(r -> r.name == "foo", report)[1]
        bar_report = filter(r -> r.name == "bar", report)[1]
        baz_report = filter(r -> r.name == "baz", report)[1]

        @test foo_report.complexity == 1
        @test bar_report.complexity == 2
        @test baz_report.complexity == 3
    end

    @testset "short form functions" begin
        code = """
        square(x) = x * x

        function cube(x)
            return x * x * x
        end

        abs_val(x) = x >= 0 ? x : -x
        """
        report = complexity_report(code)
        @test length(report) == 3

        square_report = filter(r -> r.name == "square", report)[1]
        cube_report = filter(r -> r.name == "cube", report)[1]
        abs_report = filter(r -> r.name == "abs_val", report)[1]

        @test square_report.complexity == 1
        @test cube_report.complexity == 1
        @test abs_report.complexity == 2
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
        report = complexity_report(code)
        @test length(report) == 2

        typed_report = filter(r -> r.name == "typed_func", report)[1]
        generic_report = filter(r -> r.name == "generic_func", report)[1]

        @test typed_report.complexity == 2
        @test generic_report.complexity == 2
    end
end

@testset "File and directory analysis" begin
    # Create a temporary directory with test files
    mktempdir() do tmpdir
        # Create test file 1
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

        # Create test file 2 in subdirectory
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

        @testset "file_complexity" begin
            fc = file_complexity(file1)
            @test fc.path == file1
            @test length(fc.functions) == 2
            @test fc.total_complexity == 3  # 1 + 2
        end

        @testset "directory_complexity recursive" begin
            results = directory_complexity(tmpdir; recursive = true)
            @test length(results) == 2

            total_funcs = sum(length(fc.functions) for fc in results)
            @test total_funcs == 3
        end

        @testset "directory_complexity non-recursive" begin
            results = directory_complexity(tmpdir; recursive = false)
            @test length(results) == 1
            @test results[1].path == file1
        end

        @testset "file not found" begin
            @test_throws ArgumentError file_complexity("nonexistent.jl")
        end

        @testset "directory not found" begin
            @test_throws ArgumentError directory_complexity("nonexistent_dir")
        end
    end
end

@testset "Edge cases" begin
    @testset "empty function" begin
        code = """
        function empty_func()
        end
        """
        @test cyclomatic_complexity(code) == 1
    end

    @testset "function with only comments" begin
        code = """
        function commented()
            # This is a comment
            # Another comment
        end
        """
        @test cyclomatic_complexity(code) == 1
    end

    @testset "anonymous function" begin
        code = "x -> x + 1"
        @test cyclomatic_complexity(code) == 1
    end

    @testset "anonymous function with if" begin
        code = "x -> x > 0 ? x : -x"
        @test cyclomatic_complexity(code) == 2
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
        @test cyclomatic_complexity(code) == 2
    end

    @testset "generator expression" begin
        code = """
        function with_generator()
            return sum(x for x in 1:10 if x % 2 == 0)
        end
        """
        # Generator with filter adds complexity
        @test cyclomatic_complexity(code) >= 1
    end

    @testset "comprehension with condition" begin
        code = """
        function with_comprehension()
            return [x^2 for x in 1:10 if x % 2 == 0]
        end
        """
        # Comprehension with filter
        @test cyclomatic_complexity(code) >= 1
    end
end

@testset "Macro definitions" begin
    @testset "simple macro" begin
        code = """
        macro simple_macro(x)
            return x
        end
        """
        report = complexity_report(code)
        @test length(report) == 1
        @test report[1].name == "@simple_macro"
        @test report[1].complexity == 1
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
        report = complexity_report(code)
        @test length(report) == 1
        @test report[1].name == "@conditional_macro"
        @test report[1].complexity == 2
    end
end

@testset "FunctionComplexity struct" begin
    fc = FunctionComplexity("test_func", 5, 10)
    @test fc.name == "test_func"
    @test fc.complexity == 5
    @test fc.line == 10

    # Test show method
    io = IOBuffer()
    show(io, fc)
    output = String(take!(io))
    @test occursin("test_func", output)
    @test occursin("5", output)
end

@testset "FileComplexity struct" begin
    funcs = [
        FunctionComplexity("foo", 2, 1),
        FunctionComplexity("bar", 3, 10),
    ]
    fc = FileComplexity("test.jl", funcs)
    @test fc.path == "test.jl"
    @test length(fc.functions) == 2
    @test fc.total_complexity == 5
end

@testset "max_complexity filtering" begin
    @testset "complexity_report with max_complexity" begin
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
        # Get all functions
        all_report = complexity_report(code)
        @test length(all_report) == 3

        # Filter: only complexity > 1
        filtered = complexity_report(code; max_complexity = 1)
        @test length(filtered) == 2
        @test all(f -> f.complexity > 1, filtered)

        # Filter: only complexity > 2
        filtered = complexity_report(code; max_complexity = 2)
        @test length(filtered) == 1
        @test filtered[1].name == "complex"
        @test filtered[1].complexity == 4

        # Filter: only complexity > 10 (none match)
        filtered = complexity_report(code; max_complexity = 10)
        @test isempty(filtered)
    end

    @testset "file_complexity with max_complexity" begin
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

            # All functions
            fc = file_complexity(file)
            @test length(fc.functions) == 2
            @test fc.total_complexity == 4  # 1 + 3

            # Only high complexity
            fc = file_complexity(file; max_complexity = 1)
            @test length(fc.functions) == 1
            @test fc.functions[1].name == "high"
            @test fc.total_complexity == 3
        end
    end

    @testset "directory_complexity with max_complexity" begin
        mktempdir() do tmpdir
            # File with low complexity functions
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

            # File with mixed complexity
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

            # All files
            results = directory_complexity(tmpdir)
            @test length(results) == 2

            # Only files with violations > 2
            results = directory_complexity(tmpdir; max_complexity = 2)
            @test length(results) == 1
            @test basename(results[1].path) == "mixed.jl"
            @test length(results[1].functions) == 1
            @test results[1].functions[1].name == "d"

            # No violations for high threshold
            results = directory_complexity(tmpdir; max_complexity = 10)
            @test isempty(results)
        end
    end
end

@testset "check_complexity" begin
    @testset "check_complexity on file - no violations" begin
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

            # Should not throw
            violations = check_complexity(file; max_complexity = 5)
            @test isempty(violations)
        end
    end

    @testset "check_complexity on file - with violations" begin
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

            # Should throw
            @test_throws ErrorException check_complexity(file; max_complexity = 3)

            # Should not throw with throw_on_violation=false
            violations =
                check_complexity(file; max_complexity = 3, throw_on_violation = false)
            @test length(violations) == 1
            @test violations[1].functions[1].name == "complex"
            @test violations[1].functions[1].complexity == 5
        end
    end

    @testset "check_complexity on directory" begin
        mktempdir() do tmpdir
            # Good file
            write(
                joinpath(tmpdir, "good.jl"),
                """
function ok()
    return 1
end
""",
            )

            # Bad file
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

            # Should throw due to bad.jl
            @test_throws ErrorException check_complexity(tmpdir; max_complexity = 2)

            # Get violations without throwing
            violations =
                check_complexity(tmpdir; max_complexity = 2, throw_on_violation = false)
            @test length(violations) == 1
            @test occursin("bad.jl", violations[1].path)
        end
    end

    @testset "check_complexity on module" begin
        # Test on CodeComplexity itself
        # This should pass with a reasonable threshold
        violations = check_complexity(
            CodeComplexity;
            max_complexity = 20,
            throw_on_violation = false,
        )
        # Just verify it runs without error
        @test violations isa Vector{FileComplexity}
    end

    @testset "check_complexity error message format" begin
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
                check_complexity(file; max_complexity = 2)
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

    @testset "check_complexity with default max_complexity" begin
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

            # Default max_complexity is 10, simple function should pass
            violations = check_complexity(file)
            @test isempty(violations)
        end
    end

    @testset "check_complexity path not found" begin
        @test_throws ArgumentError check_complexity("nonexistent_path")
    end
end
