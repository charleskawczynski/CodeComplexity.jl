module CodeComplexity

export cyclomatic_complexity,
    complexity_report,
    file_complexity,
    directory_complexity,
    package_complexity,
    check_complexity,
    FunctionComplexity,
    FileComplexity

"""
    FunctionComplexity

Holds complexity information for a single function.

# Fields
- `name::String`: The name of the function
- `complexity::Int`: The cyclomatic complexity value
- `line::Int`: The line number where the function is defined (0 if unknown)
"""
struct FunctionComplexity
    name::String
    complexity::Int
    line::Int
end

"""
    FileComplexity

Holds complexity information for a file.

# Fields
- `path::String`: The file path
- `functions::Vector{FunctionComplexity}`: Complexity info for each function in the file
- `total_complexity::Int`: Sum of all function complexities
"""
struct FileComplexity
    path::String
    functions::Vector{FunctionComplexity}
    total_complexity::Int
end

function FileComplexity(path::String, functions::Vector{FunctionComplexity})
    total = sum(f.complexity for f in functions; init = 0)
    FileComplexity(path, functions, total)
end

"""
    cyclomatic_complexity(expr) -> Int

Calculate the cyclomatic complexity of a Julia expression (AST).

The cyclomatic complexity is calculated by counting decision points in the code
and adding 1. Decision points include:
- `if`/`elseif` statements
- `for` loops
- `while` loops  
- `try`/`catch` blocks
- Short-circuit operators (`&&`, `||`)
- Ternary operator (`? :`)
- `@goto` statements

# Arguments
- `expr`: A Julia expression (obtained via `Meta.parse` or `quote`)

# Returns
- `Int`: The cyclomatic complexity value (minimum 1)

# Example
```julia
expr = Meta.parse(\"\"\"
function foo(x)
    if x > 0
        return x
    else
        return -x
    end
end
\"\"\")
cyclomatic_complexity(expr)  # Returns 2
```
"""
function cyclomatic_complexity(expr)
    complexity = _get_complexity(expr)
    return complexity + 1
end

"""
    cyclomatic_complexity(code::AbstractString) -> Int

Calculate the cyclomatic complexity of Julia code given as a string.

# Example
```julia
code = \"\"\"
function foo(x)
    if x > 0
        return x
    else
        return -x
    end
end
\"\"\"
cyclomatic_complexity(code)  # Returns 2
```
"""
function cyclomatic_complexity(code::AbstractString)
    expr = Meta.parse(code)
    return cyclomatic_complexity(expr)
end

# Internal function to recursively calculate complexity
function _get_complexity(expr)
    expr isa Expr || return 0
    return _get_complexity_for_head(Val(expr.head), expr.args)
end

# Sum complexity of all arguments
function _sum_args_complexity(args)
    complexity = 0
    for arg in args
        complexity += _get_complexity(arg)
    end
    return complexity
end

# Default: recurse into children
_get_complexity_for_head(::Val, args) = _sum_args_complexity(args)

# Heads that add 1 and recurse into all args
_get_complexity_for_head(::Val{:if}, args) = 1 + _sum_args_complexity(args)
_get_complexity_for_head(::Val{:elseif}, args) = 1 + _sum_args_complexity(args)
_get_complexity_for_head(::Val{:for}, args) = 1 + _sum_args_complexity(args)
_get_complexity_for_head(::Val{:while}, args) = 1 + _sum_args_complexity(args)
_get_complexity_for_head(::Val{:catch}, args) = 1 + _sum_args_complexity(args)
_get_complexity_for_head(::Val{:&&}, args) = 1 + _sum_args_complexity(args)
_get_complexity_for_head(::Val{:||}, args) = 1 + _sum_args_complexity(args)
_get_complexity_for_head(::Val{:?}, args) = 1 + _sum_args_complexity(args)

# try block: count catch clauses
# Structure: try body [catch var catchbody] [finally finallybody]
function _get_complexity_for_head(::Val{:try}, args)
    complexity = 0
    for (i, arg) in enumerate(args)
        if arg isa Expr
            complexity += _get_complexity(arg)
        elseif arg isa Symbol && i == 2
            # catch variable - if there's a catch block, add 1
            if length(args) >= 3 && args[3] !== false
                complexity += 1
            end
        end
    end
    # Handle case where catch exists (position 3) but no catch variable
    if length(args) >= 3 && args[3] !== false && !(args[2] isa Symbol)
        complexity += 1
    end
    return complexity
end

# macrocall: check for @goto and recurse into arguments
function _get_complexity_for_head(::Val{:macrocall}, args)
    complexity = 0
    if length(args) > 0 && args[1] === Symbol("@goto")
        complexity += 1
    end
    # Recurse into macro arguments (skip the macro name and line number)
    for arg in args[3:end]
        complexity += _get_complexity(arg)
    end
    return complexity
end

# Filter functions by max_complexity threshold
function _filter_by_complexity(
    functions::Vector{FunctionComplexity},
    max_complexity::Union{Int, Nothing},
)
    if max_complexity === nothing
        return functions
    end
    return filter(f -> f.complexity > max_complexity, functions)
end

# Filter file complexities and their functions by max_complexity
function _filter_files_by_complexity(
    files::Vector{FileComplexity},
    max_complexity::Union{Int, Nothing},
)
    if max_complexity === nothing
        return files
    end

    filtered_files = FileComplexity[]
    for fc in files
        filtered_funcs = _filter_by_complexity(fc.functions, max_complexity)
        if !isempty(filtered_funcs)
            push!(filtered_files, FileComplexity(fc.path, filtered_funcs))
        end
    end
    return filtered_files
end

"""
    complexity_report(code::AbstractString; max_complexity::Union{Int,Nothing}=nothing) -> Vector{FunctionComplexity}

Analyze Julia code and return complexity information for each function defined.

# Arguments
- `code::AbstractString`: Julia source code as a string
- `max_complexity::Union{Int,Nothing}=nothing`: If specified, only return functions with 
  complexity greater than this threshold. Useful for finding functions that exceed a limit.

# Returns
- `Vector{FunctionComplexity}`: A vector of complexity info for each function

# Example
```julia
code = \"\"\"
function foo(x)
    if x > 0
        return x
    end
    return 0
end

function bar(x, y)
    return x + y
end
\"\"\"
report = complexity_report(code)
# Returns 2 FunctionComplexity objects

# Only get functions with complexity > 1
violations = complexity_report(code; max_complexity=1)
# Returns only foo (complexity 2)
```
"""
function complexity_report(
    code::AbstractString;
    max_complexity::Union{Int, Nothing} = nothing,
)
    expr = _parse_code(code)
    functions = _extract_functions(expr)
    return _filter_by_complexity(functions, max_complexity)
end

# Parse code string into AST, handling different Julia versions and edge cases
function _parse_code(code::AbstractString)
    # Try Meta.parseall first (available in Julia 1.9+) as it handles whole files better
    if isdefined(Meta, :parseall)
        try
            return Meta.parseall(code)
        catch
            # Fall back to begin-end wrapping
        end
    end
    # Fall back: wrap in begin...end block
    return Meta.parse("begin\n$code\nend")
end

# Extract function definitions and their complexities
function _extract_functions(
    expr,
    results::Vector{FunctionComplexity} = FunctionComplexity[],
)
    if expr isa Expr
        if expr.head === :function || expr.head === :(=)
            # Check if this is a function definition
            name, is_func = _get_function_name(expr)
            if is_func
                comp = cyclomatic_complexity(expr)
                line = _get_line_number(expr)
                push!(results, FunctionComplexity(name, comp, line))
            else
                # Not a function, recurse into children
                for arg in expr.args
                    _extract_functions(arg, results)
                end
            end
        elseif expr.head === :->
            # Anonymous function / lambda
            comp = cyclomatic_complexity(expr)
            line = _get_line_number(expr)
            push!(results, FunctionComplexity("<anonymous>", comp, line))
        elseif expr.head === :macro
            # Macro definition
            if length(expr.args) >= 1
                name = "@" * string(_extract_name(expr.args[1]))
                comp = cyclomatic_complexity(expr)
                line = _get_line_number(expr)
                push!(results, FunctionComplexity(name, comp, line))
            end
        else
            # Recurse into children
            for arg in expr.args
                _extract_functions(arg, results)
            end
        end
    end
    return results
end

# Get function name from a function definition expression
function _get_function_name(expr)
    if expr.head === :function
        if length(expr.args) >= 1
            return string(_extract_name(expr.args[1])), true
        end
    elseif expr.head === :(=)
        # Short form function: f(x) = ...
        if length(expr.args) >= 1 && expr.args[1] isa Expr
            if expr.args[1].head === :call || expr.args[1].head === :where
                return string(_extract_name(expr.args[1])), true
            end
        end
    end
    return "", false
end

# Extract the name from a function signature
function _extract_name(expr)
    if expr isa Symbol
        return expr
    elseif expr isa Expr
        if expr.head === :call && length(expr.args) >= 1
            return _extract_name(expr.args[1])
        elseif expr.head === :where && length(expr.args) >= 1
            return _extract_name(expr.args[1])
        elseif expr.head === :curly && length(expr.args) >= 1
            return _extract_name(expr.args[1])
        elseif expr.head === :(::) && length(expr.args) >= 1
            return _extract_name(expr.args[1])
        elseif expr.head === :(.) && length(expr.args) >= 2
            # Qualified name like Module.func
            return Symbol(
                string(_extract_name(expr.args[1])),
                ".",
                string(expr.args[2].value),
            )
        end
    end
    return :unknown
end

# Get line number from expression if available
function _get_line_number(expr)
    if expr isa Expr
        for arg in expr.args
            if arg isa LineNumberNode
                return arg.line
            elseif arg isa Expr && arg.head === :line && length(arg.args) >= 1
                return arg.args[1]
            end
        end
        # Recurse to find line number
        for arg in expr.args
            line = _get_line_number(arg)
            if line > 0
                return line
            end
        end
    end
    return 0
end

"""
    file_complexity(filepath::AbstractString; max_complexity::Union{Int,Nothing}=nothing) -> FileComplexity

Analyze a Julia source file and return complexity information.

# Arguments
- `filepath::AbstractString`: Path to a Julia source file
- `max_complexity::Union{Int,Nothing}=nothing`: If specified, only include functions with 
  complexity greater than this threshold.

# Returns
- `FileComplexity`: Complexity information for the file

# Example
```julia
fc = file_complexity("src/MyModule.jl")
println("Total complexity: ", fc.total_complexity)
for func in fc.functions
    println("  ", func.name, ": ", func.complexity)
end

# Find functions exceeding complexity threshold
fc = file_complexity("src/MyModule.jl"; max_complexity=10)
for func in fc.functions
    println("WARNING: ", func.name, " has complexity ", func.complexity)
end
```
"""
function file_complexity(
    filepath::AbstractString;
    max_complexity::Union{Int, Nothing} = nothing,
)
    if !isfile(filepath)
        throw(ArgumentError("File not found: $filepath"))
    end
    code = read(filepath, String)
    functions = complexity_report(code; max_complexity = max_complexity)
    return FileComplexity(filepath, functions)
end

"""
    directory_complexity(dirpath::AbstractString; recursive::Bool=true, max_complexity::Union{Int,Nothing}=nothing) -> Vector{FileComplexity}

Analyze all Julia source files in a directory and return complexity information.

# Arguments
- `dirpath::AbstractString`: Path to a directory
- `recursive::Bool=true`: Whether to search subdirectories recursively
- `max_complexity::Union{Int,Nothing}=nothing`: If specified, only include functions with 
  complexity greater than this threshold. Files with no violations are excluded.

# Returns
- `Vector{FileComplexity}`: Complexity information for each Julia file found

# Example
```julia
results = directory_complexity("src/")
for fc in results
    println(fc.path, ": ", fc.total_complexity)
end

# Find all functions exceeding complexity limit
violations = directory_complexity("src/"; max_complexity=10)
for fc in violations
    for func in fc.functions
        println(fc.path, ":", func.line, " ", func.name, " complexity=", func.complexity)
    end
end
```
"""
function directory_complexity(
    dirpath::AbstractString;
    recursive::Bool = true,
    max_complexity::Union{Int, Nothing} = nothing,
)
    if !isdir(dirpath)
        throw(ArgumentError("Directory not found: $dirpath"))
    end

    results = FileComplexity[]

    if recursive
        for (root, dirs, files) in walkdir(dirpath)
            for file in files
                if endswith(file, ".jl")
                    filepath = joinpath(root, file)
                    try
                        fc = file_complexity(filepath; max_complexity = max_complexity)
                        # Only include files that have functions (after filtering)
                        if max_complexity === nothing || !isempty(fc.functions)
                            push!(results, fc)
                        end
                    catch e
                        @warn "Failed to analyze $filepath" exception = e
                    end
                end
            end
        end
    else
        for file in readdir(dirpath)
            if endswith(file, ".jl")
                filepath = joinpath(dirpath, file)
                if isfile(filepath)
                    try
                        fc = file_complexity(filepath; max_complexity = max_complexity)
                        # Only include files that have functions (after filtering)
                        if max_complexity === nothing || !isempty(fc.functions)
                            push!(results, fc)
                        end
                    catch e
                        @warn "Failed to analyze $filepath" exception = e
                    end
                end
            end
        end
    end

    return results
end

"""
    package_complexity(pkg::Module; max_complexity::Union{Int,Nothing}=nothing) -> Vector{FileComplexity}

Analyze all Julia source files in a package and return complexity information.

# Arguments
- `pkg::Module`: A loaded Julia module/package
- `max_complexity::Union{Int,Nothing}=nothing`: If specified, only include functions with 
  complexity greater than this threshold.

# Returns
- `Vector{FileComplexity}`: Complexity information for each Julia file in the package

# Example
```julia
using MyPackage
results = package_complexity(MyPackage)
for fc in results
    println(fc.path, ": ", fc.total_complexity)
end

# Check for functions exceeding complexity limit
violations = package_complexity(MyPackage; max_complexity=15)
@test isempty(violations)  # Fail if any function exceeds limit
```
"""
function package_complexity(pkg::Module; max_complexity::Union{Int, Nothing} = nothing)
    # Get the package directory from the module's path
    pkg_path = pathof(pkg)
    if pkg_path === nothing
        throw(ArgumentError("Cannot determine source path for module $pkg"))
    end

    # Get the src directory (parent of the main module file)
    src_dir = dirname(pkg_path)

    return directory_complexity(src_dir; recursive = true, max_complexity = max_complexity)
end

"""
    package_complexity(pkg_name::AbstractString; max_complexity::Union{Int,Nothing}=nothing) -> Vector{FileComplexity}

Analyze all Julia source files in a package given by name.

# Arguments
- `pkg_name::AbstractString`: Name of a package (must be in the load path)
- `max_complexity::Union{Int,Nothing}=nothing`: If specified, only include functions with 
  complexity greater than this threshold.

# Returns
- `Vector{FileComplexity}`: Complexity information for each Julia file in the package

# Example
```julia
results = package_complexity("CodeComplexity")

# Find violations
violations = package_complexity("CodeComplexity"; max_complexity=10)
```
"""
function package_complexity(
    pkg_name::AbstractString;
    max_complexity::Union{Int, Nothing} = nothing,
)
    # Find the package in the load path
    for depot in DEPOT_PATH
        pkg_dir = joinpath(depot, "packages", pkg_name)
        if isdir(pkg_dir)
            # Find the latest version
            versions = readdir(pkg_dir)
            if !isempty(versions)
                latest = joinpath(pkg_dir, last(sort(versions)), "src")
                if isdir(latest)
                    return directory_complexity(
                        latest;
                        recursive = true,
                        max_complexity = max_complexity,
                    )
                end
            end
        end
    end

    # Try to find in dev packages or current directory
    for path in LOAD_PATH
        if path isa AbstractString
            candidate = joinpath(path, pkg_name, "src")
            if isdir(candidate)
                return directory_complexity(
                    candidate;
                    recursive = true,
                    max_complexity = max_complexity,
                )
            end
            # Also try without src subdirectory
            candidate = joinpath(path, pkg_name)
            if isdir(candidate)
                return directory_complexity(
                    candidate;
                    recursive = true,
                    max_complexity = max_complexity,
                )
            end
        end
    end

    throw(ArgumentError("Package not found: $pkg_name"))
end

"""
    check_complexity(path_or_pkg; max_complexity::Int=10, throw_on_violation::Bool=true) -> Vector{FileComplexity}

Check that no functions exceed the specified complexity threshold. Useful for tests and CI.

# Arguments
- `path_or_pkg`: A file path, directory path, or loaded Module to analyze
- `max_complexity::Int=10`: Maximum allowed complexity (functions with complexity > this value are violations)
- `throw_on_violation::Bool=true`: If true, throws an error when violations are found

# Returns
- `Vector{FileComplexity}`: Files containing functions that exceed the threshold

# Throws
- `ErrorException`: If `throw_on_violation=true` and any function exceeds the limit

# Example
```julia
# In your test suite:
using CodeComplexity
using MyPackage

@testset "Code complexity" begin
    # This will fail if any function has complexity > 10
    check_complexity(MyPackage; max_complexity=10)
end

# In a pre-commit hook or CI script:
check_complexity("src/"; max_complexity=15)

# Get violations without throwing:
violations = check_complexity("src/"; max_complexity=10, throw_on_violation=false)
for fc in violations
    for func in fc.functions
        println("VIOLATION: \$(fc.path):\$(func.line) \$(func.name) (complexity=\$(func.complexity))")
    end
end
```
"""
function check_complexity(
    path::AbstractString;
    max_complexity::Int = 10,
    throw_on_violation::Bool = true,
)
    violations = if isfile(path)
        fc = file_complexity(path; max_complexity = max_complexity)
        isempty(fc.functions) ? FileComplexity[] : [fc]
    elseif isdir(path)
        directory_complexity(path; recursive = true, max_complexity = max_complexity)
    else
        throw(ArgumentError("Path not found: $path"))
    end

    _handle_violations(violations, max_complexity, throw_on_violation)
    return violations
end

function check_complexity(
    pkg::Module;
    max_complexity::Int = 10,
    throw_on_violation::Bool = true,
)
    violations = package_complexity(pkg; max_complexity = max_complexity)
    _handle_violations(violations, max_complexity, throw_on_violation)
    return violations
end

function _handle_violations(
    violations::Vector{FileComplexity},
    max_complexity::Int,
    throw_on_violation::Bool,
)
    if throw_on_violation && !isempty(violations)
        # Build error message
        msg = IOBuffer()
        println(msg, "Cyclomatic complexity violations (max_complexity=$max_complexity):")
        for fc in violations
            for func in fc.functions
                line_info = func.line > 0 ? ":$(func.line)" : ""
                println(
                    msg,
                    "  $(fc.path)$line_info: $(func.name) has complexity $(func.complexity)",
                )
            end
        end
        error(String(take!(msg)))
    end
end

# Pretty printing
function Base.show(io::IO, fc::FunctionComplexity)
    line_info = fc.line > 0 ? " (line $(fc.line))" : ""
    print(io, "FunctionComplexity(\"$(fc.name)\", complexity=$(fc.complexity)$line_info)")
end

function Base.show(io::IO, ::MIME"text/plain", fc::FileComplexity)
    println(io, "FileComplexity: $(fc.path)")
    println(io, "  Total complexity: $(fc.total_complexity)")
    println(io, "  Functions ($(length(fc.functions))):")
    for func in fc.functions
        line_info = func.line > 0 ? " (line $(func.line))" : ""
        println(io, "    $(func.name): $(func.complexity)$line_info")
    end
end

end # module CodeComplexity
