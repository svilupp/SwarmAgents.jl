using Test
using SwarmAgents
using PromptingTools
using PromptingTools: ToolMessage, UserMessage

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
            push!(history, ToolMessage("output", nothing, "id", "id", Dict(), tool, :default))
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
            push!(history, ToolMessage("output", nothing, "id", "id", Dict(), "repeated_tool", :default))
        end

        @test num_subsequent_repeats(history) == 4

        # Test with mixed tools
        push!(history, ToolMessage("output", nothing, "id", "id", Dict(), "different_tool", :default))
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
            push!(history, ToolMessage("output", nothing, "id", "id", Dict(), "tool1", :default))
            push!(history, ToolMessage("output", nothing, "id", "id", Dict(), "tool2", :default))
        end
        @test isnothing(run_termination_checks(history, agent, io, checks))

        # Test message output
        output = String(take!(io))
        @test occursin("Termination condition triggered", output)
    end
end
