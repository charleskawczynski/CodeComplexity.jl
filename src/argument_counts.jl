"""
    FunctionArguments

Per-function parameter count for PLR0913-style checks (inspired by Ruff’s `too-many-arguments`).

# Fields
- `name::String`: Function (or macro) name; `\"<anonymous>\"` for `->` lambdas
- `arg_count::Int`: Number of parameters in the signature (positional + keyword slots)
- `line::Int`: Line number of the definition (0 if unknown)
"""
struct FunctionArguments
    name::String
    arg_count::Int
    line::Int
end

"""
    FileArguments

Argument-count summary for one source file.

# Fields
- `path::String`: File path
- `functions::Vector{FunctionArguments}`: One entry per scanned definition in the file
- `total_arguments::Int`: Sum of `arg_count` over `functions`
"""
struct FileArguments
    path::String
    functions::Vector{FunctionArguments}
    total_arguments::Int
end

function FileArguments(path::String, functions::Vector{FunctionArguments})
    total = sum(f.arg_count for f in functions; init = 0)
    FileArguments(path, functions, total)
end

function _filter_by_arg_count(
    functions::Vector{FunctionArguments},
    max_args::Union{Int, Nothing},
)
    if max_args === nothing
        return functions
    end
    return filter(f -> f.arg_count > max_args, functions)
end

function _argument_ignore_key(x)::String
    if x isa Symbol || x isa AbstractString
        return string(x)
    elseif applicable(nameof, x)
        return string(nameof(x))
    else
        return string(x)
    end
end

function _argument_ignore_set(ignore)::Union{Nothing, Set{String}}
    ignore === nothing && return nothing
    return Set{String}(_argument_ignore_key(x) for x in ignore)
end

function _filter_by_ignored_names(
    functions::Vector{FunctionArguments},
    ignore_set::Union{Nothing, Set{String}},
)
    ignore_set === nothing && return functions
    isempty(ignore_set) && return functions
    return filter(f -> !(f.name in ignore_set), functions)
end

"""
    argument_count_report(code::AbstractString; max_args::Union{Int,Nothing}=nothing, ignore=nothing) -> Vector{FunctionArguments}

Count parameters on each function-like definition in `code`. When `max_args` is set (default in
[`check_argument_count`](@ref) is 5, matching Ruff’s `lint.pylint.max-args`), only definitions with
`arg_count > max_args` are returned.

If `ignore` is an iterable, those definitions are omitted before any `max_args` filter. Each entry is
turned into a name string: `Symbol` / `AbstractString` use `string(x)`; any other `x` with
`nameof(x)` defined (e.g. a `Function`, type / constructor `T`, or `Core.Builtin`) uses
`string(nameof(x))`, matching how names appear in source. Macros still use the stored form
`"@foo"` (e.g. `ignore=("@generated",)`). Lambdas are named `"<anonymous>"`.

# Caveats

- Matching is by **unqualified** name: the same name in any module is ignored.
- **Macros** are usually passed as `Symbol` / `String` in the `"@name"` form; there is often no stable callable.
- **Complex types** (e.g. `Union{...}`): `nameof` may not match a simple source identifier; prefer symbols/strings.
- **`->` lambdas** use the name `"<anonymous>"` in reports and in `ignore`.

See also: Ruff rule [PLR0913](https://docs.astral.sh/ruff/rules/too-many-arguments/).
"""
function argument_count_report(
    code::AbstractString;
    max_args::Union{Int, Nothing} = nothing,
    ignore = nothing,
)
    expr = _parse_code(code)
    functions = _extract_argument_counts(expr)
    ignore_set = _argument_ignore_set(ignore)
    functions = _filter_by_ignored_names(functions, ignore_set)
    return _filter_by_arg_count(functions, max_args)
end

function _unwrap_where(sig)
    while sig isa Expr && sig.head === :where && !isempty(sig.args)
        sig = sig.args[1]
    end
    return sig
end

"""
    _count_call_parameters(call::Expr) -> Int

Count parameters in `Expr(:call, f, args...)` after `f`: each positional slot counts as one;
`Expr(:parameters, ...)` contributes one per keyword/slot inside. Aligned with Ruff’s PLR0913
(`too-many-arguments` / `lint.pylint.max-args`), not with older Pylint exclusions.
"""
function _count_call_parameters(call::Expr)
    (call.head === :call && length(call.args) >= 1) || return 0
    n = 0
    for i in 2:length(call.args)
        a = call.args[i]
        if a isa Expr && a.head === :parameters
            n += length(a.args)
        else
            n += 1
        end
    end
    return n
end

function _count_tuple_parameters(tup::Expr)
    tup.head === :tuple || return 0
    n = 0
    for a in tup.args
        if a isa Expr && a.head === :parameters
            n += length(a.args)
        else
            n += 1
        end
    end
    return n
end

function _argument_count_long_function(expr::Expr)
    length(expr.args) < 1 && return 0
    sig = _unwrap_where(expr.args[1])
    if sig isa Symbol
        return 0
    end
    if sig isa Expr && sig.head === :call
        return _count_call_parameters(sig)
    end
    return 0
end

function _argument_count_short_function(expr::Expr)
    length(expr.args) < 1 && return 0
    sig = _unwrap_where(expr.args[1])
    if sig isa Expr && sig.head === :call
        return _count_call_parameters(sig)
    end
    return 0
end

function _argument_count_lambda(expr::Expr)
    length(expr.args) < 1 && return 0
    sig = _unwrap_where(expr.args[1])
    if sig isa Symbol
        return 1
    end
    if sig isa Expr && sig.head === :call
        return _count_call_parameters(sig)
    end
    if sig isa Expr && sig.head === :tuple
        return _count_tuple_parameters(sig)
    end
    return 0
end

function _argument_count_macro(expr::Expr)
    length(expr.args) < 1 && return 0
    sig = _unwrap_where(expr.args[1])
    if sig isa Symbol
        return 0
    end
    if sig isa Expr && sig.head === :call
        return _count_call_parameters(sig)
    end
    return 0
end

function _extract_argument_counts(
    expr,
    results::Vector{FunctionArguments} = FunctionArguments[],
)
    if expr isa Expr
        if expr.head === :function || expr.head === :(=)
            name, is_func = _get_function_name(expr)
            if is_func
                n = if expr.head === :function
                    _argument_count_long_function(expr)
                else
                    _argument_count_short_function(expr)
                end
                line = _get_line_number(expr)
                push!(results, FunctionArguments(name, n, line))
            else
                for arg in expr.args
                    _extract_argument_counts(arg, results)
                end
            end
        elseif expr.head === :->
            n = _argument_count_lambda(expr)
            line = _get_line_number(expr)
            push!(results, FunctionArguments("<anonymous>", n, line))
        elseif expr.head === :macro
            if length(expr.args) >= 1
                name = "@" * string(_extract_name(expr.args[1]))
                n = _argument_count_macro(expr)
                line = _get_line_number(expr)
                push!(results, FunctionArguments(name, n, line))
            end
        else
            for arg in expr.args
                _extract_argument_counts(arg, results)
            end
        end
    end
    return results
end

"""
    file_argument_counts(filepath::AbstractString; max_args::Union{Int,Nothing}=nothing, ignore=nothing) -> FileArguments

Like [`file_complexity`](@ref), but reports parameter counts per definition (PLR0913-style).
"""
function file_argument_counts(
    filepath::AbstractString;
    max_args::Union{Int, Nothing} = nothing,
    ignore = nothing,
)
    if !isfile(filepath)
        throw(ArgumentError("File not found: $filepath"))
    end
    code = read(filepath, String)
    functions = argument_count_report(code; max_args = max_args, ignore = ignore)
    return FileArguments(filepath, functions)
end

"""
    directory_argument_counts(dirpath::AbstractString; recursive::Bool=true, max_args::Union{Int,Nothing}=nothing, ignore=nothing) -> Vector{FileArguments}

Like [`directory_complexity`](@ref), but for parameter-count analysis.
"""
function directory_argument_counts(
    dirpath::AbstractString;
    recursive::Bool = true,
    max_args::Union{Int, Nothing} = nothing,
    ignore = nothing,
)
    if !isdir(dirpath)
        throw(ArgumentError("Directory not found: $dirpath"))
    end

    results = FileArguments[]

    if recursive
        for (root, dirs, files) in walkdir(dirpath)
            for file in files
                if endswith(file, ".jl")
                    filepath = joinpath(root, file)
                    try
                        fa = file_argument_counts(
                            filepath;
                            max_args = max_args,
                            ignore = ignore,
                        )
                        if max_args === nothing || !isempty(fa.functions)
                            push!(results, fa)
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
                        fa = file_argument_counts(
                            filepath;
                            max_args = max_args,
                            ignore = ignore,
                        )
                        if max_args === nothing || !isempty(fa.functions)
                            push!(results, fa)
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
    package_argument_counts(pkg::Module; max_args::Union{Int,Nothing}=nothing, ignore=nothing) -> Vector{FileArguments}

Like [`package_complexity`](@ref), but for parameter counts.
"""
function package_argument_counts(
    pkg::Module;
    max_args::Union{Int, Nothing} = nothing,
    ignore = nothing,
)
    pkg_path = pathof(pkg)
    if pkg_path === nothing
        throw(ArgumentError("Cannot determine source path for module $pkg"))
    end
    src_dir = dirname(pkg_path)
    return directory_argument_counts(
        src_dir;
        recursive = true,
        max_args = max_args,
        ignore = ignore,
    )
end

"""
    package_argument_counts(pkg_name::AbstractString; max_args::Union{Int,Nothing}=nothing, ignore=nothing) -> Vector{FileArguments}

Like [`package_complexity`](@ref) with a package name string, but for parameter counts.
"""
function package_argument_counts(
    pkg_name::AbstractString;
    max_args::Union{Int, Nothing} = nothing,
    ignore = nothing,
)
    for depot in DEPOT_PATH
        pkg_dir = joinpath(depot, "packages", pkg_name)
        if isdir(pkg_dir)
            versions = readdir(pkg_dir)
            if !isempty(versions)
                latest = joinpath(pkg_dir, last(sort(versions)), "src")
                if isdir(latest)
                    return directory_argument_counts(
                        latest;
                        recursive = true,
                        max_args = max_args,
                        ignore = ignore,
                    )
                end
            end
        end
    end

    for path in LOAD_PATH
        if path isa AbstractString
            candidate = joinpath(path, pkg_name, "src")
            if isdir(candidate)
                return directory_argument_counts(
                    candidate;
                    recursive = true,
                    max_args = max_args,
                    ignore = ignore,
                )
            end
            candidate = joinpath(path, pkg_name)
            if isdir(candidate)
                return directory_argument_counts(
                    candidate;
                    recursive = true,
                    max_args = max_args,
                    ignore = ignore,
                )
            end
        end
    end

    throw(ArgumentError("Package not found: $pkg_name"))
end

"""
    check_argument_count(path_or_pkg; max_args::Int=5, throw_on_violation::Bool=true, ignore=nothing) -> Vector{FileArguments}

Enforce a maximum parameter count per definition (Ruff PLR0913 / `lint.pylint.max-args` default: 5).
Violations are definitions with `arg_count > max_args`.

# Arguments
- `path_or_pkg`: File path, directory path, or loaded `Module`
- `max_args::Int=5`: Allowed parameters; definitions with more are violations
- `throw_on_violation::Bool=true`: If true, throw when any violation is found
- `ignore`: Optional iterable of names or live callables/types to exclude (same as [`argument_count_report`](@ref); see its **Caveats** section)

# Returns
- `Vector{FileArguments}`: Files that contain violations (after filtering), or empty if none
"""
function check_argument_count(
    path::AbstractString;
    max_args::Int = 5,
    throw_on_violation::Bool = true,
    ignore = nothing,
)
    violations = if isfile(path)
        fa = file_argument_counts(path; max_args = max_args, ignore = ignore)
        isempty(fa.functions) ? FileArguments[] : [fa]
    elseif isdir(path)
        directory_argument_counts(
            path;
            recursive = true,
            max_args = max_args,
            ignore = ignore,
        )
    else
        throw(ArgumentError("Path not found: $path"))
    end

    _handle_argument_count_violations(violations, max_args, throw_on_violation)
    return violations
end

function check_argument_count(
    pkg::Module;
    max_args::Int = 5,
    throw_on_violation::Bool = true,
    ignore = nothing,
)
    violations = package_argument_counts(pkg; max_args = max_args, ignore = ignore)
    _handle_argument_count_violations(violations, max_args, throw_on_violation)
    return violations
end

function _handle_argument_count_violations(
    violations::Vector{FileArguments},
    max_args::Int,
    throw_on_violation::Bool,
)
    if throw_on_violation && !isempty(violations)
        msg = IOBuffer()
        println(
            msg,
            "Too-many-arguments violations (max_args=$max_args; PLR0913-style):",
        )
        for fa in violations
            for func in fa.functions
                line_info = func.line > 0 ? ":$(func.line)" : ""
                println(
                    msg,
                    "  $(fa.path)$line_info: $(func.name) has $(func.arg_count) parameters",
                )
            end
        end
        error(String(take!(msg)))
    end
end

function Base.show(io::IO, fa::FunctionArguments)
    line_info = fa.line > 0 ? " (line $(fa.line))" : ""
    print(
        io,
        "FunctionArguments(\"$(fa.name)\", arg_count=$(fa.arg_count)$line_info)",
    )
end

function Base.show(io::IO, ::MIME"text/plain", fa::FileArguments)
    println(io, "FileArguments: $(fa.path)")
    println(io, "  Total parameters (summed): $(fa.total_arguments)")
    println(io, "  Definitions ($(length(fa.functions))):")
    for func in fa.functions
        line_info = func.line > 0 ? " (line $(func.line))" : ""
        println(io, "    $(func.name): $(func.arg_count) parameters$line_info")
    end
end
