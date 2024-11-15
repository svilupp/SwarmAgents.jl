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

    @testset "tool_output" begin
        # Test struct with output property
        struct TestStructWithOutput
            output::String
            other::Int
        end
        test_struct = TestStructWithOutput("test output", 42)

        # Test struct without output property
        struct TestStructNoOutput
            value::Int
        end
        test_struct_no_output = TestStructNoOutput(42)

        # Test struct with custom tool_output method
        struct TestStructCustomOutput
            data::String
        end
        # Define custom tool_output method
        SwarmAgents.tool_output(x::TestStructCustomOutput) = "Custom: $(x.data)"
        test_struct_custom = TestStructCustomOutput("custom data")

        # Test string passthrough
        @test tool_output("direct string") == "direct string"

        # Test struct with output property
        @test tool_output(test_struct) == "test output"

        # Test struct without output property (uses show method)
        output = tool_output(test_struct_no_output)
        @test contains(output, "42")
        @test contains(output, "TestStructNoOutput")

        # Test custom tool_output method
        @test tool_output(test_struct_custom) == "Custom: custom data"

        # Test other types (using show method)
        @test tool_output(42) == "42"
        @test tool_output([1, 2, 3]) == "[1, 2, 3]"

        # Test Dict type
        test_dict = Dict("key" => "value")
        @test tool_output(test_dict) == "Dict(\"key\" => \"value\")"
    end
end
