using Test
using SwarmAgents
using PromptingTools
using PromptingTools: AbstractMessage, UserMessage, SystemMessage, AIToolRequest,
                     ToolMessage, TestEchoOpenAISchema

# Define test functions at module level
func1() = nothing
func5() = "test"

@testset "Workflow" begin

    @testset "handle_tool_calls!" begin
        agent = Agent(name = "TestAgent")
        add_tools!(agent, [Tool(func1)])
        session = Session(agent)
        add_rules!(session, Tool(func5))  # Add func5 as a session rule

        # Test tool from agent's tool_map
        history = AbstractMessage[PT.AIToolRequest(tool_calls = [ToolMessage(;
            tool_call_id = "1", raw = "{}",
            name = "func1", args = Dict())])]

        result = handle_tool_calls!(agent, history, session)
        @test length(result.history) == 2
        @test length(session.artifacts) == 1
        @test session.artifacts[end] === nothing  # func1 returns nothing

        # Test tool from session rules
        history = AbstractMessage[PT.AIToolRequest(tool_calls = [ToolMessage(;
            tool_call_id = "2", raw = "{}",
            name = "func5", args = Dict())])]

        result = handle_tool_calls!(agent, history, session)
        @test length(result.history) == 2
        @test result.history[end].content == "test"
        @test length(session.artifacts) == 2
        @test session.artifacts[end] == "test"  # func5 returns "test"

        # Test with no active agent
        push!(history, PT.AIToolRequest(; content = "Hi"))
        result_no_agent = handle_tool_calls!(nothing, history, session)
        @test result_no_agent.active_agent === nothing

        # Test with empty tool calls
        empty_history = AbstractMessage[PT.AIToolRequest(;
            content = "hi", tool_calls = ToolMessage[])]
        result_empty = handle_tool_calls!(agent, empty_history, session)
        @test length(result_empty.history) == 1

        # Test with custom io
        io = IOBuffer()
        session_with_io = Session(agent; io=io)
        add_rules!(session_with_io, Tool(func5))
        test_history = AbstractMessage[PT.AIToolRequest(
            content="Testing tool execution",
            tool_calls = [ToolMessage(
                content=nothing,
                raw="{}",
                tool_call_id="test",
                name="func5",
                args=Dict{Symbol,Any}())])]
        result_io = handle_tool_calls!(session_with_io.agent, test_history, session_with_io)
        output = String(take!(io))
        @test contains(output, "Tool Request") || contains(output, "Tool Output")
    end

    @testset "update_system_message!" begin
        agent = Agent(name = "TestAgent", instructions = "New instructions")
        history = AbstractMessage[PT.UserMessage("Hello")]

        updated_history = update_system_message!(history, agent)
        @test length(updated_history) == 2
        @test PT.issystemmessage(updated_history[1])
        @test updated_history[1].content == "New instructions"

        # Test with existing system message
        history_with_system = AbstractMessage[PT.SystemMessage("Old instructions"),
            PT.UserMessage("Hello")]
        updated_history = update_system_message!(history_with_system, agent)
        @test length(updated_history) == 2
        @test updated_history[1].content == "New instructions"

        # Test with no active agent
        no_change_history = update_system_message!(history, nothing)
        @test no_change_history == history
    end

    @testset "run_full_turn" begin
        response1 = Dict(
            :id => "123",
            :choices => [
                Dict(
                :message => Dict(:content => "test",
                    :tool_calls => [
                        Dict(:id => "123",
                        :function => Dict(
                            :name => "func1",
                            :arguments => JSON3.write(Dict())))
                    ]),
                :finish_reason => "tool_calls")
            ],
            :usage => Dict(:total_tokens => 20, :prompt_tokens => 15, :completion_tokens => 5)
        )
        schema = TestEchoOpenAISchema(; response = response1, status = 200)
        PT.register_model!(; name = "mocktools", schema)

        agent = Agent(
            name = "TestAgent", instructions = "You are a test agent.", model = "mocktools")
        add_tools!(agent, Tool(func1))
        messages = AbstractMessage[PT.UserMessage("Hello")]

        # Test with both agent tools and session rules
        session = Session(agent)
        add_rules!(session, Tool(func5))

        response = run_full_turn(agent, messages, session; max_turns = 1)
        @test response isa Response
        @test !isempty(response.messages)
        @test response.messages[end].name == "func1"
        @test length(session.artifacts) == 1

        # Test with custom io
        io = IOBuffer()
        session_with_io = Session(agent; io=io)
        add_rules!(session_with_io, Tool(func5))
        updated_session = run_full_turn!(session_with_io, "Hello")
        @test length(updated_session.messages) > 1
        @test updated_session.agent === agent
        @test updated_session.messages[end].name == "func1"
        output = String(take!(io))
        @test !isempty(output)

        # Test with tool from session rules
        response2 = Dict(
            :id => "124",
            :choices => [
                Dict(
                :message => Dict(:content => "test",
                    :tool_calls => [
                        Dict(:id => "124",
                        :function => Dict(
                            :name => "func5",
                            :arguments => JSON3.write(Dict())))
                    ]),
                :finish_reason => "tool_calls")
            ],
            :usage => Dict(:total_tokens => 20, :prompt_tokens => 15, :completion_tokens => 5)
        )
        schema = TestEchoOpenAISchema(; response = response2, status = 200)
        PT.register_model!(; name = "mocktools2", schema)

        agent2 = Agent(
            name = "TestAgent2", instructions = "You are a test agent.", model = "mocktools2")
        session2 = Session(agent2)
        add_rules!(session2, Tool(func5))

        response = run_full_turn(agent2, messages, session2; max_turns = 1)
        @test response isa Response
        @test !isempty(response.messages)
        @test response.messages[end].name == "func5"
        @test length(session2.artifacts) == 1
        @test session2.artifacts[end] == "test"
    end

    @testset "add_transfers!" begin
        @testset "function naming convention" begin
            session = Session()

            # Create test agents with different name formats
            booking_agent = Agent(name="Booking Agent")
            support_agent = Agent(name="Support Agent")
            sales_agent = Agent(name="Sales Agent")

            # Add agents to session
            session.agent_map[:booking] = booking_agent
            session.agent_map[:support] = support_agent
            session.agent_map[:sales] = sales_agent

            # Add transfer tools
            add_transfers!(session)

            # Verify tool names follow snake_case convention
            @test haskey(booking.tool_map, "transfer_to_support_agent")
            @test haskey(booking.tool_map, "transfer_to_sales_agent")
            @test haskey(support.tool_map, "transfer_to_booking_agent")
            @test haskey(support.tool_map, "transfer_to_sales_agent")
            @test haskey(sales.tool_map, "transfer_to_booking_agent")
            @test haskey(sales.tool_map, "transfer_to_support_agent")

            # Verify no self-transfer tools were created
            @test !haskey(booking.tool_map, "transfer_to_booking_agent")
            @test !haskey(support.tool_map, "transfer_to_support_agent")
            @test !haskey(sales.tool_map, "transfer_to_sales_agent")
        end

        @testset "handover message handling" begin
            session = Session()

            # Create test agents
            agent1 = Agent(name="Agent One")
            agent2 = Agent(name="Agent Two")

            # Add agents to session
            session.agent_map[:one] = agent1
            session.agent_map[:two] = agent2

            # Add transfer tools
            add_transfers!(session)

            # Test handover message
            handover_msg = "Transferring to specialized agent for technical support"
            transfer_fn = agent1.tool_map["transfer_to_agent_two"]

            # Execute transfer
            result = transfer_fn.function(handover_msg)

            # Verify handover message was added to session
            @test length(session.messages) == 1
            @test session.messages[1] isa SystemMessage
            @test session.messages[1].content == handover_msg

            # Verify correct AgentRef is returned
            @test result isa AgentRef
            @test result.name == Symbol("Agent Two")
        end

        @testset "end-to-end agent transfers" begin
            session = Session()

            # Create agents with different specialties
            booking = Agent(name="Booking Agent", instructions="Handle flight bookings")
            support = Agent(name="Support Agent", instructions="Handle customer support")

            # Add agents to session
            session.agent_map[:booking] = booking
            session.agent_map[:support] = support

            # Add transfer tools
            add_transfers!(session)

            # Test complete transfer flow
            booking_to_support = booking.tool_map["transfer_to_support_agent"]
            support_to_booking = support.tool_map["transfer_to_booking_agent"]

            # Transfer from booking to support
            handover_msg1 = "Customer needs help with existing booking"
            result1 = booking_to_support.function(handover_msg1)

            # Verify first transfer
            @test result1 isa AgentRef
            @test result1.name == Symbol("Support Agent")
            @test session.messages[end].content == handover_msg1

            # Transfer back to booking
            handover_msg2 = "Customer wants to modify their booking"
            result2 = support_to_booking.function(handover_msg2)

            # Verify second transfer
            @test result2 isa AgentRef
            @test result2.name == Symbol("Booking Agent")
            @test session.messages[end].content == handover_msg2
        end
    end
end
