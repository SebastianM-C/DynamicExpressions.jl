using DynamicExpressions
using DynamicExpressions: parse_expression
using DynamicExpressions: get_tree, get_operators, get_variable_names
using Zygote
using Test

@testset "Expression Initialization" begin
    let
        tree = Node(Float64; feature=1)
        operators = OperatorEnum(; binary_operators=[+, *], unary_operators=[sin])
        variable_names = ["x"]

        expr = Expression(tree, (; operators, variable_names))

        @test get_tree(expr) === tree
        @test get_operators(expr, nothing) === operators
        @test get_variable_names(expr, nothing) === variable_names

        copy_operators = OperatorEnum(; binary_operators=[+])
        copy_variable_names = ["y"]

        @test get_operators(expr, copy_operators) === copy_operators
        @test get_variable_names(expr, copy_variable_names) === copy_variable_names

        @inferred copy_node(expr)
        @test copy(expr) == expr
        @test hash(copy(expr)) == hash(expr)

        expr2 = Expression(Node(; op=1, l=tree), (; operators, variable_names))
        @test copy_node(expr2) != expr
        @test hash(copy(expr2)) != hash(expr)
    end
end

@testset "Evaluation" begin
    let
        ex = @parse_expression(
            sin(2.0 * x1 + exp(x2 + 5.0)),
            operators = OperatorEnum(;
                binary_operators=[+, -, *, /], unary_operators=[sin, cos, exp]
            ),
            variable_names = [:x1, :x2],
        )

        X = rand(Float64, 2, 10) .+ 1
        expected = @. sin(2.0 * X[1, :] + exp(X[2, :] + 5.0))
        expected_dy_dx1 = @. 2.0 * cos(2.0 * X[1, :] + exp(X[2, :] + 5.0))

        if VERSION >= v"1.9"
            @test_nowarn begin
                result = ex(X)
                @test result ≈ expected
                result_grad = ex'(X)
                @test result_grad[1, :] ≈ expected_dy_dx1
            end
        end
    end
end

@testset "Nested repeat operators" begin
    let
        ex = @parse_expression(
            a + b + c + a + b + c,
            variable_names = [:a, :b, :c],
            operators = OperatorEnum(; binary_operators=[+])
        )
        @test sprint((io, ex) -> show(io, MIME"text/plain"(), ex), ex) ==
            "((((a + b) + c) + a) + b) + c"
    end
end

@testset "Utilities" begin
    let
        operators = OperatorEnum(;
            binary_operators=[+, -, *, /], unary_operators=[sin, cos, exp]
        )
        variable_names = [:a, :b, :c]
        ex = @parse_expression(
            cos(a * 1.5 - 0.3) * b + exp(0.5 - c * c),
            variable_names = variable_names,
            operators = operators
        )
        @test string(ex) == string(copy(ex))
        @test ex !== copy(ex)
        @test hash(ex) == copy(hash(ex))

        t = ex.tree
        modified_ex = @parse_expression(
            $t + 1.5, variable_names = variable_names, operators = operators
        )
        s1 = sprint((io, ex) -> show(io, MIME"text/plain"(), ex), ex)
        s2 = sprint((io, ex) -> show(io, MIME"text/plain"(), ex), modified_ex)
        @test s2 == "($s1) + 1.5"
        @test hash(ex) != hash(modified_ex)
    end
end

@testset "Edge cases" begin
    let
        operators = OperatorEnum(;
            binary_operators=[+, -, *, /], unary_operators=[sin, cos, exp]
        )
        variable_names = [:a, :b, :c]
        ex = @parse_expression(
            cos(a * 1.5 - 0.3) * b + exp(0.5 - c * c),
            variable_names = variable_names,
            operators = operators
        )
        @test_throws ArgumentError @parse_expression(
            $ex + 1.5, variable_names = variable_names, operators = operators
        )
        if VERSION >= v"1.9"
            @test_throws "Cannot parse an expression as a value in another expression. " @parse_expression(
                $ex + 1.5, variable_names = variable_names, operators = operators
            )
        end
        @eval struct Foo
            x::$(typeof(ex.tree))
        end
        foo = Foo(ex.tree)
        @test_throws ArgumentError @parse_expression(
            $(foo).x + 1.5, variable_names = variable_names, operators = operators
        )
        if VERSION >= v"1.9"
            @test_throws "Unrecognized expression type" @parse_expression(
                $(foo).x + 1.5, variable_names = variable_names, operators = operators
            )
        end
    end
end
