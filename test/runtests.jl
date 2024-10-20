using Swarm
using PromptingTools
const PT = PromptingTools
using JSON3
using Test
using Aqua

@testset "Swarm.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(Swarm)
    end
    include("types.jl")
    include("utils.jl")
end
