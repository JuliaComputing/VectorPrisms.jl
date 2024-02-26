using VectorPrisms
using Test
using Aqua

@testset "VectorPrisms.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(VectorPrisms)
    end
    # Write your tests here.
end
