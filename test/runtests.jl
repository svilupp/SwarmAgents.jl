using SwarmAgents
using PromptingTools
using PromptingTools: AbstractMessage, UserMessage, SystemMessage, AIToolRequest,
                     ToolMessage, TestEchoOpenAISchema, Models
using JSON3
using Test
using Aqua

@testset "SwarmAgents.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(SwarmAgents)
    end
    include("types.jl")
    include("utils.jl")
end
