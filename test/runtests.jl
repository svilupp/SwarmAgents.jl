using Swarm
using Test
using Aqua

@testset "Swarm.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(Swarm)
    end
    # Write your tests here.
end
