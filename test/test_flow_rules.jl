using Test
using SwarmAgents
using PromptingTools
using PromptingTools: ToolMessage, UserMessage, AIToolRequestMessage, ToolCall

@testset "Flow Rules" begin
    @testset "TerminationCycleCheck" begin
        # Test constructor validation
        @test_throws ArgumentError TerminationCycleCheck(1, 3)
        @test_throws ArgumentError TerminationCycleCheck(3, 1)

        check = TerminationCycleCheck(3, 3)
        history = []

        # Create repeating cycle
        tool_sequence = ["tool1", "tool2", "tool3"]
        for _ in 1:3, tool in tool_sequence
            push!(history, ToolMessage("", nothing, "id", "id", Dict(), tool, :default))
        end

        @test is_cycle(history, n=3, span=3)
        @test !is_cycle(history, n=4, span=3)

        # Test with privacy wrapper
        private_history = map(msg -> PrivateMessage(msg, ["agent"]), history)
        @test is_cycle(private_history, n=3, span=3)
    end

    @testset "TerminationRepeatCheck" begin
        @test_throws ArgumentError TerminationRepeatCheck(1)

        check = TerminationRepeatCheck(3)
        history = []

        # Create repeated tools
        for _ in 1:4
            push!(history, ToolMessage("", nothing, "id", "id", Dict(), "repeated_tool", :default))
        end

        @test num_subsequent_repeats(history) == 4

        # Test with mixed tools
        push!(history, ToolMessage("", nothing, "id", "id", Dict(), "different_tool", :default))
        @test num_subsequent_repeats(history) == 4

        # Test with privacy wrapper
        private_history = map(msg -> PrivateMessage(msg, ["agent"]), history)
        @test num_subsequent_repeats(private_history) == 4
    end

    @testset "TerminationGenericCheck" begin
        check = TerminationGenericCheck((history, agent) -> length(history) > 3 ? nothing : agent)
        agent = Agent(name="TestAgent")
        history = []

        # Test termination condition
        for i in 1:4
            push!(history, UserMessage("message $i"))
        end

        @test isnothing(check.callable(history, agent))
        @test !isnothing(check.callable(history[1:2], agent))
    end

    @testset "run_termination_checks Integration" begin
        agent = Agent(name="TestAgent")
        history = []
        io = IOBuffer()

        # Create checks
        checks = [
            TerminationCycleCheck(2, 2),
            TerminationRepeatCheck(3),
            TerminationGenericCheck((h, a) -> length(h) > 5 ? nothing : a)
        ]

        # Test no termination
        @test !isnothing(run_termination_checks(history, agent, io, checks))

        # Test cycle termination
        for _ in 1:2
            push!(history, ToolMessage("", nothing, "id", "id", Dict(), "tool1", :default))
            push!(history, ToolMessage("", nothing, "id", "id", Dict(), "tool2", :default))
        end
        @test isnothing(run_termination_checks(history, agent, io, checks))

        # Test message output
        output = String(take!(io))
        @test occursin("Termination condition triggered", output)
    end

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

        # Test get_allowed_tools
        @test get_allowed_tools(rule, Symbol[]) == ["tool1"]
        @test get_allowed_tools(rule, [:tool1]) == ["tool2"]
        @test isempty(get_allowed_tools(rule, [:tool1, :tool2, :tool3]))
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

        # Test get_allowed_tools
        @test get_allowed_tools(rule, Symbol[]) == ["tool1"]
        @test Set(get_allowed_tools(rule, [:tool1])) == Set(["tool1", "tool2"])
        @test Set(get_allowed_tools(rule, [:tool1, :tool2])) == Set(["tool1", "tool2", "tool3"])
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

        # Test combining rules
        used_tools = Symbol[]
        allowed = get_allowed_tools([fixed_order, prerequisites], used_tools)
        @test isempty(allowed) # tool1 from fixed_order but not allowed by prerequisites

        # Test after using tool1
        used_tools = [:tool1]
        allowed = get_allowed_tools([fixed_order, prerequisites], used_tools)
        @test allowed == ["tool2"] # tool2 is next in fixed_order and allowed by prerequisites

        # Test with vcat
        used_tools = Symbol[]
        allowed = get_allowed_tools([fixed_order, prerequisites], used_tools; combine=vcat)
        @test Set(allowed) == Set(["tool1", "tool2"]) # tool1 from fixed_order and tool2 from prerequisites
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
end
