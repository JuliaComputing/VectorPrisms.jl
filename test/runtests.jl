using VectorPrisms
using Test
using Aqua

@testset "VectorPrisms.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(VectorPrisms)
    end

    @testset "basic functionality" begin
        include("basic_functionality.jl")
    end

    @testset "StaticArrays Compatibility" begin
        include("staticarrays_compatibility.jl")
    end
end
