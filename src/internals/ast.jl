# Shared AST helpers used by every metric: parsing source strings and
# extracting names / line numbers from function-like expressions.

function _parse_code(code::AbstractString)
    return parseall(Expr, code; ignore_errors = true)
end

function _get_function_name(expr)
    if expr.head === :function
        if length(expr.args) >= 1
            return string(_extract_name(expr.args[1])), true
        end
    elseif expr.head === :(=)
        if length(expr.args) >= 1 && expr.args[1] isa Expr
            if expr.args[1].head === :call || expr.args[1].head === :where
                return string(_extract_name(expr.args[1])), true
            end
        end
    end
    return "", false
end

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
            return Symbol(
                string(_extract_name(expr.args[1])),
                ".",
                string(expr.args[2].value),
            )
        end
    end
    return :unknown
end

function _get_line_number(expr)
    if expr isa Expr
        for arg in expr.args
            if arg isa LineNumberNode
                return arg.line
            elseif arg isa Expr && arg.head === :line && length(arg.args) >= 1
                return arg.args[1]
            end
        end
        for arg in expr.args
            line = _get_line_number(arg)
            if line > 0
                return line
            end
        end
    end
    return 0
end
