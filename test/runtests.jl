using SwarmAgents
using PromptingTools
const PT = PromptingTools
using JSON3
using Test
using Aqua

# Include shared test utilities first
include("shared_test_utils.jl")

@testset "SwarmAgents.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(SwarmAgents)
    end
    include("test_core_types.jl")
    include("test_utils.jl")
    include("test_privacy.jl")
    include("test_flow_rules.jl")
    include("test_workflow.jl")
    include("test_swarm.jl")
    include("test_tool_errors.jl")
end
