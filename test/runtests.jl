using SwarmAgents
using PromptingTools
const PT = PromptingTools
using JSON3
using Test
using Aqua

@testset "SwarmAgents.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(SwarmAgents)
    end
    include("test_types.jl")
    include("test_utils.jl")
    include("test_swarm.jl")
    include("test_privacy.jl")
    include("test_agent_utils.jl")
    include("test_flow_rules.jl")
end
