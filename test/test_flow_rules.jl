using Test
using SwarmAgents
using PromptingTools
using PromptingTools: ToolMessage, UserMessage, AIMessage, Tool
using SwarmAgents: PrivateMessage

@testset "Flow Rules" begin
    @testset "TerminationCycleCheck" begin
        # Test constructor validation
        @test_throws ArgumentError TerminationCycleCheck(1, 3)
        @test_throws ArgumentError TerminationCycleCheck(3, 1)

        check = TerminationCycleCheck(3, 3)
        history = []

        # Create repeating cycle with generic tool names
        tool_sequence = ["tool_a", "tool_b", "tool_c"]
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
        check = TerminationGenericCheck(callable=(history, agent) -> length(history) > 3 ? nothing : agent)
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
            TerminationGenericCheck(callable=(h, a) -> length(h) > 5 ? nothing : a)
        ]

        # Test no termination
        @test !isnothing(run_termination_checks(history, agent, io, checks))

        # Test cycle termination
        for _ in 1:2
            push!(history, ToolMessage("", nothing, "id", "id", Dict(), "tool_a", :default))
            push!(history, ToolMessage("", nothing, "id", "id", Dict(), "tool_b", :default))
        end
        @test isnothing(run_termination_checks(history, agent, io, checks))

        # Test message output
        output = String(take!(io))
        @test occursin("Termination condition triggered", output)
    end

    @testset "FixedOrder" begin
        # Create a session with tools
        session = Session()
        tool_a = Tool(name="tool_a", parameters=Dict(), description="Test tool A", strict=false, callable=identity)
        tool_b = Tool(name="tool_b", parameters=Dict(), description="Test tool B", strict=false, callable=identity)
        tool_c = Tool(name="tool_c", parameters=Dict(), description="Test tool C", strict=false, callable=identity)
        all_tools = ["tool_a", "tool_b", "tool_c"]

        # Create FixedOrder rule with keyword constructor
        rule = FixedOrder(order=["tool_a", "tool_b", "tool_c"])
        add_rules!(session, rule)
        @test length(session.rules) == 1
        @test session.rules[1] === rule

        # Test initial state (only first tool allowed)
        history = PT.AbstractMessage[]
        @test get_allowed_tools(rule, String[], all_tools) == ["tool_a"]

        # Test after using first tool
        push!(history, AIMessage(content="Using tool tool_a"))
        @test get_allowed_tools(rule, ["tool_a"], all_tools) == ["tool_b"]

        # Test after using all tools
        @test isempty(get_allowed_tools(rule, ["tool_a", "tool_b", "tool_c"], all_tools))

        # Test passthrough when no order defined
        empty_rule = FixedOrder()
        @test get_allowed_tools(empty_rule, String[], all_tools) == all_tools
    end

    @testset "FixedPrerequisites" begin
        # Create a session with tools
        session = Session()
        tool_a = Tool(name="tool_a", parameters=Dict(), description="Test tool A", strict=false, callable=identity)
        tool_b = Tool(name="tool_b", parameters=Dict(), description="Test tool B", strict=false, callable=identity)
        tool_c = Tool(name="tool_c", parameters=Dict(), description="Test tool C", strict=false, callable=identity)
        all_tools = ["tool_a", "tool_b", "tool_c"]

        # Create FixedPrerequisites rule with explicit prerequisites
        prereqs = Dict("tool_b" => ["tool_a"], "tool_c" => ["tool_a", "tool_b"])
        rule = FixedPrerequisites(prerequisites=prereqs)
        add_rules!(session, rule)
        @test length(session.rules) == 1
        @test session.rules[1] === rule

        # Test initial state (tool_a and any unrestricted tools allowed)
        @test Set(get_allowed_tools(rule, String[], all_tools)) == Set(["tool_a"])

        # Test after using first tool (first and second allowed)
        @test Set(get_allowed_tools(rule, ["tool_a"], all_tools)) == Set(["tool_a", "tool_b"])

        # Test after using first and second tools (all tools allowed)
        @test Set(get_allowed_tools(rule, ["tool_a", "tool_b"], all_tools)) == Set(["tool_a", "tool_b", "tool_c"])

        # Test passthrough when no prerequisites defined
        empty_rule = FixedPrerequisites()
        @test get_allowed_tools(empty_rule, String[], all_tools) == all_tools
    end

    @testset "Multiple Rules" begin
        # Create a session with tools
        session = Session()
        tool_a = Tool(name="tool_a", parameters=Dict(), description="Test tool A", strict=false, callable=identity)
        tool_b = Tool(name="tool_b", parameters=Dict(), description="Test tool B", strict=false, callable=identity)
        tool_c = Tool(name="tool_c", parameters=Dict(), description="Test tool C", strict=false, callable=identity)
        all_tools = ["tool_a", "tool_b", "tool_c"]

        # Add both types of rules
        fixed_order = FixedOrder(order=["tool_a", "tool_b"])
        prereqs = Dict("tool_b" => ["tool_a"], "tool_c" => ["tool_a", "tool_b"])
        prerequisites = FixedPrerequisites(prerequisites=prereqs)

        # Add rules to session
        add_rules!(session, [fixed_order, prerequisites])
        @test length(session.rules) == 2
        @test session.rules[1] === fixed_order
        @test session.rules[2] === prerequisites

        # Test combining rules with union (default)
        used_tools = String[]
        allowed = get_allowed_tools(session.rules, used_tools, all_tools)
        @test allowed == ["tool_a"] # tool_a is first in order and has no prerequisites

        # Test after using tool_a
        used_tools = ["tool_a"]
        allowed = get_allowed_tools(session.rules, used_tools, all_tools)
        @test allowed == ["tool_b"] # tool_b is next in fixed_order and allowed by prerequisites

        # Test with vcat (should deduplicate like union)
        used_tools = ["tool_a"]
        allowed = get_allowed_tools(session.rules, used_tools, all_tools; combine=vcat)
        @test allowed == ["tool_b"] # Should be same as union, deduplicated

        # Test with intersect
        used_tools = String[]
        allowed = get_allowed_tools(session.rules, used_tools, all_tools; combine=intersect)
        @test Set(allowed) == Set(["tool_a"]) # tool_a is first in both rules

        # Test passthrough when no tool rules present
        termination_rule = TerminationCycleCheck(2, 2)
        @test get_allowed_tools([termination_rule], used_tools, all_tools) == all_tools

        # Test deduplication with duplicate tools in input
        duplicate_tools = ["tool_a", "tool_b", "tool_a", "tool_c", "tool_b"]
        @test length(get_allowed_tools(session.rules, duplicate_tools, all_tools)) == length(unique(duplicate_tools))

        # Test strict intersection with all_tools
        @testset "Strict intersection with all_tools" begin
            # Test FixedOrder with tools not in all_tools
            extended_order = FixedOrder(order=["tool_a", "tool_d", "tool_b"])
            @test get_allowed_tools(extended_order, String[], all_tools) == ["tool_a"]
            @test get_allowed_tools(extended_order, ["tool_a"], all_tools) == ["tool_b"]

            # Test FixedPrerequisites with tools not in all_tools
            extended_prereqs = Dict(
                "tool_b" => ["tool_a"],
                "tool_d" => ["tool_a"],  # tool_d not in all_tools
                "tool_c" => ["tool_a", "tool_d"]  # requires non-existent tool
            )
            prereq_rule = FixedPrerequisites(prerequisites=extended_prereqs)

            # Initial state should only show tool_a
            @test Set(get_allowed_tools(prereq_rule, String[], all_tools)) == Set(["tool_a"])

            # After tool_a, only tool_b should be available (tool_d is not in all_tools)
            @test Set(get_allowed_tools(prereq_rule, ["tool_a"], all_tools)) == Set(["tool_a", "tool_b"])

            # tool_c should never be available as its prerequisite tool_d isn't in all_tools
            @test Set(get_allowed_tools(prereq_rule, ["tool_a", "tool_b"], all_tools)) == Set(["tool_a", "tool_b"])
        end
    end

    @testset "get_used_tools" begin
        # Create history with tool usage via AIToolRequests
        history = PT.AbstractMessage[]
        push!(history, PT.AIToolRequest(tool_calls = [ToolMessage(;
            tool_call_id = "1", raw = "{}", name = "tool_a", args = Dict())]))
        push!(history, PT.AIToolRequest(tool_calls = [ToolMessage(;
            tool_call_id = "2", raw = "{}", name = "tool_b", args = Dict())]))

        used_tools = get_used_tools(history)
        @test used_tools == ["tool_a", "tool_b"]

        # Test empty history
        @test isempty(get_used_tools(PT.AbstractMessage[]))

        # Test history with non-tool messages
        history = [PT.UserMessage("test")]
        @test isempty(get_used_tools(history))
    end
