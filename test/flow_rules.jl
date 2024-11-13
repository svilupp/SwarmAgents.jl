using Test
using SwarmAgents
using PromptingTools
const PT = PromptingTools

@testset "Flow Rules" begin
    @testset "FixedOrder" begin
        # Create an agent with tools
        agent = Agent(name="TestAgent")
        tool1 = Tool(name="tool1", func=identity)
        tool2 = Tool(name="tool2", func=identity)
        tool3 = Tool(name="tool3", func=identity)
        add_tools!(agent, [tool1, tool2, tool3])

        # Create FixedOrder rule
        rule = FixedOrder([:tool1, :tool2, :tool3])
        add_rules!(agent, rule)

        # Test initial state (only first tool allowed)
        history = PT.AbstractMessage[]
        tools = collect(values(agent.tool_map))
        filtered_tools = apply_rules(history, agent, tools)
        @test length(filtered_tools) == 1
        @test first(filtered_tools).name == "tool1"

        # Test after using first tool
        push!(history, PT.AIToolRequestMessage(tool_calls=[PT.ToolCall(name="tool1", args="")]))
        filtered_tools = apply_rules(history, agent, tools)
        @test length(filtered_tools) == 1
        @test first(filtered_tools).name == "tool2"
    end

    @testset "FixedPrerequisites" begin
        # Create an agent with tools
        agent = Agent(name="TestAgent")
        tool1 = Tool(name="tool1", func=identity)
        tool2 = Tool(name="tool2", func=identity)
        tool3 = Tool(name="tool3", func=identity)
        add_tools!(agent, [tool1, tool2, tool3])

        # Create FixedPrerequisites rule
        rule = FixedPrerequisites([:tool1, :tool2, :tool3])
        add_rules!(agent, rule)

        # Test initial state (only first tool allowed)
        history = PT.AbstractMessage[]
        tools = collect(values(agent.tool_map))
        filtered_tools = apply_rules(history, agent, tools)
        @test length(filtered_tools) == 1
        @test first(filtered_tools).name == "tool1"

        # Test after using first tool (first and second allowed)
        push!(history, PT.AIToolRequestMessage(tool_calls=[PT.ToolCall(name="tool1", args="")]))
        filtered_tools = apply_rules(history, agent, tools)
        @test length(filtered_tools) == 2
        @test Set(t.name for t in filtered_tools) == Set(["tool1", "tool2"])

        # Test after using second tool (all tools allowed)
        push!(history, PT.AIToolRequestMessage(tool_calls=[PT.ToolCall(name="tool2", args="")]))
        filtered_tools = apply_rules(history, agent, tools)
        @test length(filtered_tools) == 3
        @test Set(t.name for t in filtered_tools) == Set(["tool1", "tool2", "tool3"])
    end

    @testset "Multiple Rules" begin
        agent = Agent(name="TestAgent")
        tool1 = Tool(name="tool1", func=identity)
        tool2 = Tool(name="tool2", func=identity)
        tool3 = Tool(name="tool3", func=identity)
        add_tools!(agent, [tool1, tool2, tool3])

        # Add both types of rules
        fixed_order = FixedOrder([:tool1, :tool2])
        prerequisites = FixedPrerequisites([:tool2, :tool3])
        add_rules!(agent, [fixed_order, prerequisites])

        # Test initial state (only tool1 allowed due to FixedOrder)
        history = PT.AbstractMessage[]
        tools = collect(values(agent.tool_map))
        filtered_tools = apply_rules(history, agent, tools)
        @test length(filtered_tools) == 1
        @test first(filtered_tools).name == "tool1"
    end
end
