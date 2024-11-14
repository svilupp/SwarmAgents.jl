using Test
using SwarmAgents
using PromptingTools
using PromptingTools: UserMessage, AIToolRequest, ToolMessage

@testset "Utilities" begin
    @testset "scrub_agent_name" begin
        agent = Agent(name = "Test Agent", model = "gpt-3.5-turbo")
        @test scrub_agent_name(agent) == "Test_Agent"

        agent = Agent(name = "Test Agent 2", model = "gpt-3.5-turbo")
        @test scrub_agent_name(agent) == "Test_Agent_2"
    end

    @testset "print_progress" begin
        # Setup
        agent = Agent(name = "TestAgent")

        # Test with io = nothing
        io = nothing
        msg = AIToolRequest("content", Vector{ToolMessage}(), "test", nothing, (1,1), 0.0, nothing, nothing, nothing, nothing, nothing, nothing, :default)
        @test isnothing(print_progress(io, agent, msg))

        # Test with StringIO to capture output
        io = IOBuffer()

        # Test AIToolRequest with content
        msg = AIToolRequest("content", Vector{ToolMessage}(), "test", nothing, (1,1), 0.0, nothing, nothing, nothing, nothing, nothing, nothing, :default)
        print_progress(io, agent, msg)
        output = String(take!(io))
        @test contains(output, "Assistant (TestAgent): content")
        @test contains(output, ">>")

        # Test ToolMessage without content
        msg = ToolMessage(nothing, nothing, "test_tool", "test_tool", Dict{Symbol,Any}(:arg1 => "value1"), nothing, :default)
        print_progress(io, agent, msg)
        output = String(take!(io))
        @test contains(output, "Tool Request: test_tool")
        @test contains(output, "args: ")
        @test contains(output, "arg1")

        # Test ToolMessage with content
        msg = ToolMessage("output", nothing, "test_tool", "test_tool", Dict{Symbol,Any}(), nothing, :default)
        print_progress(io, agent, msg)
        output = String(take!(io))
        @test contains(output, "Tool Output: output")
    end
end
