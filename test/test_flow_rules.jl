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
            push!(history, ToolMessage("", nothing, "id", "id", Dict(), "tool1", :default))
            push!(history, ToolMessage("", nothing, "id", "id", Dict(), "tool2", :default))
        end
        @test isnothing(run_termination_checks(history, agent, io, checks))

        # Test message output
        output = String(take!(io))
        @test occursin("Termination condition triggered", output)
    end

    @testset "FixedOrder" begin
        # Create a session with tools
        session = Session()
        tool1 = Tool(name="tool1", parameters=Dict(), description="Test tool 1", strict=false, callable=identity)
        tool2 = Tool(name="tool2", parameters=Dict(), description="Test tool 2", strict=false, callable=identity)
        tool3 = Tool(name="tool3", parameters=Dict(), description="Test tool 3", strict=false, callable=identity)

        # Create FixedOrder rule with keyword constructor
        rule = FixedOrder(order=[:tool1, :tool2, :tool3])
        add_rules!(session, rule)

        # Test initial state (only first tool allowed)
        history = PT.AbstractMessage[]
        tools = [tool1, tool2, tool3]
        @test get_allowed_tools(rule, Symbol[]) == ["tool1"]

        # Test after using first tool
        push!(history, AIMessage(content="Using tool tool1"))
        @test get_allowed_tools(rule, [:tool1]) == ["tool2"]

        # Test after using all tools
        @test isempty(get_allowed_tools(rule, [:tool1, :tool2, :tool3]))
    end

    @testset "FixedPrerequisites" begin
        # Create a session with tools
        session = Session()
        tool1 = Tool(name="tool1", parameters=Dict(), description="Test tool 1", strict=false, callable=identity)
        tool2 = Tool(name="tool2", parameters=Dict(), description="Test tool 2", strict=false, callable=identity)
        tool3 = Tool(name="tool3", parameters=Dict(), description="Test tool 3", strict=false, callable=identity)

        # Create FixedPrerequisites rule with explicit prerequisites
        prereqs = Dict(:tool2 => [:tool1], :tool3 => [:tool1, :tool2])
        rule = FixedPrerequisites(prerequisites=prereqs)
        add_rules!(session, rule)

        # Test initial state (only tool1 allowed)
        @test get_allowed_tools(rule, Symbol[]) == ["tool1"]

        # Test after using first tool (first and second allowed)
        @test Set(get_allowed_tools(rule, [:tool1])) == Set(["tool1", "tool2"])

        # Test after using first and second tools (all tools allowed)
        @test Set(get_allowed_tools(rule, [:tool1, :tool2])) == Set(["tool1", "tool2", "tool3"])
    end

    @testset "Multiple Rules" begin
        # Create a session with tools
        session = Session()
        tool1 = Tool(name="tool1", parameters=Dict(), description="Test tool 1", strict=false, callable=identity)
        tool2 = Tool(name="tool2", parameters=Dict(), description="Test tool 2", strict=false, callable=identity)
        tool3 = Tool(name="tool3", parameters=Dict(), description="Test tool 3", strict=false, callable=identity)

        # Add both types of rules
        fixed_order = FixedOrder(order=[:tool1, :tool2])
        prereqs = Dict(:tool2 => [:tool1], :tool3 => [:tool1, :tool2])
        prerequisites = FixedPrerequisites(prerequisites=prereqs)

        # Test combining rules
        used_tools = Symbol[]
        allowed = get_allowed_tools([fixed_order, prerequisites], used_tools)
        @test allowed == ["tool1"] # tool1 is first in order and has no prerequisites

        # Test after using tool1
        used_tools = [:tool1]
        allowed = get_allowed_tools([fixed_order, prerequisites], used_tools)
        @test allowed == ["tool2"] # tool2 is next in fixed_order and allowed by prerequisites

        # Test with vcat
        used_tools = Symbol[]
        allowed = get_allowed_tools([fixed_order, prerequisites], used_tools; combine=vcat)
        @test Set(allowed) == Set(["tool1"]) # tool1 is first in both rules
    end

    @testset "get_used_tools" begin
        # Create history with tool usage
        history = PT.AbstractMessage[]
        push!(history, AIMessage(content="Using tool tool1"))
        push!(history, AIMessage(content="Using tool tool2"))

        used_tools = get_used_tools(history)
        @test used_tools == [:tool1, :tool2]

        # Test empty history
        @test isempty(get_used_tools(PT.AbstractMessage[]))

        # Test history with non-tool messages
        history = [PT.UserMessage("test")]
        @test isempty(get_used_tools(history))
    end
end
