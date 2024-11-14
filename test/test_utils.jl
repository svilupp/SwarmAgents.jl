using Test
using SwarmAgents
using PromptingTools
using PromptingTools: UserMessage, AIMessage, ToolMessage, Tool

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
        msg = AIMessage(content="Testing tool call")
        @test isnothing(print_progress(io, agent, msg))

        # Test with StringIO to capture output
        io = IOBuffer()

        # Test AIMessage with content
        msg = AIMessage(content="Testing tool call")
        print_progress(io, agent, msg)
        output = String(take!(io))
        @test contains(output, "TestAgent")
        @test contains(output, ">>")

        # Test ToolMessage without content
        msg = ToolMessage(nothing, nothing, "test_tool", "test_tool", Dict{Symbol,Any}(:arg1 => "value1"), "test_tool", :default)
        print_progress(io, agent, msg)
        output = String(take!(io))
        @test contains(output, "Using tool: test_tool")
        @test contains(output, "arg1")
        @test contains(output, "value1")

        # Test ToolMessage with content
        msg = ToolMessage("output", nothing, "test_tool", "test_tool", Dict{Symbol,Any}(), "test_tool", :default)
        print_progress(io, agent, msg)
        output = String(take!(io))
        @test contains(output, "Tool response: output")
    end
end
