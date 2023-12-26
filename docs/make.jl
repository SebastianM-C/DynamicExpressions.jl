using Documenter
using DynamicExpressions

makedocs(;
    sitename="DynamicExpressions.jl",
    authors="Miles Cranmer",
    doctest=false,
    clean=true,
    format=Documenter.HTML(),
    warnonly=true,
)

deploydocs(; repo="github.com/SymbolicML/DynamicExpressions.jl.git")
