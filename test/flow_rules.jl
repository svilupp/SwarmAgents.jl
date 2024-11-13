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

    @testset "get_used_tools" begin
        # Create history with tool usage
        history = PT.AbstractMessage[]
        push!(history, PT.AIToolRequestMessage(tool_calls=[PT.ToolCall(name="tool1", args="")]))
        push!(history, PT.AIToolRequestMessage(tool_calls=[PT.ToolCall(name="tool2", args="")]))

        used_tools = get_used_tools(history)
        @test used_tools == [:tool1, :tool2]

        # Test empty history
        @test isempty(get_used_tools(PT.AbstractMessage[]))

        # Test history with non-tool messages
        history = [PT.UserMessage("test")]
        @test isempty(get_used_tools(history))
    end

    @testset "get_allowed_tools" begin
        # Test FixedOrder
        rule = FixedOrder([:tool1, :tool2, :tool3])

        # No tools used
        @test get_allowed_tools(rule, Symbol[]) == ["tool1"]

        # First tool used
        @test get_allowed_tools(rule, [:tool1]) == ["tool2"]

        # All tools used
        @test isempty(get_allowed_tools(rule, [:tool1, :tool2, :tool3]))

        # Test FixedPrerequisites
        rule = FixedPrerequisites([:tool1, :tool2, :tool3])

        # No tools used
        @test get_allowed_tools(rule, Symbol[]) == ["tool1"]

        # First tool used
        @test Set(get_allowed_tools(rule, [:tool1])) == Set(["tool1", "tool2"])

        # First two tools used
        @test Set(get_allowed_tools(rule, [:tool1, :tool2])) == Set(["tool1", "tool2", "tool3"])
    end

    @testset "combine rules" begin
        fixed_order = FixedOrder([:tool1, :tool2, :tool3])
        prerequisites = FixedPrerequisites([:tool2, :tool3])
        rules = [fixed_order, prerequisites]

        # Test default (intersect)
        used_tools = Symbol[]
        allowed = get_allowed_tools(rules, used_tools)
        @test isempty(allowed) # tool1 from fixed_order but not allowed by prerequisites

        # Test after using tool1
        used_tools = [:tool1]
        allowed = get_allowed_tools(rules, used_tools)
        @test allowed == ["tool2"] # tool2 is next in fixed_order and allowed by prerequisites

        # Test with vcat
        used_tools = Symbol[]
        allowed = get_allowed_tools(rules, used_tools; combine=vcat)
        @test Set(allowed) == Set(["tool1", "tool2"]) # tool1 from fixed_order and tool2 from prerequisites
    end
end
