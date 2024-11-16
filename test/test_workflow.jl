using Test
using SwarmAgents
using PromptingTools
using PromptingTools: AbstractMessage, UserMessage, SystemMessage, AIToolRequest,
                     ToolMessage, TestEchoOpenAISchema
using JSON3

@testset "Workflow" begin

    @testset "handle_tool_calls!" begin
        agent = Agent(name = "TestAgent")

        # Add tools to agent
        add_tools!(agent, [
            Tool(func1),
            Tool(name="struct_tool", callable=func_struct_output),
            Tool(name="custom_tool", callable=func_no_output)
        ])
        session = Session(agent)
        add_rules!(session, FixedOrder(Tool(func5)))

        # Test original tool from agent's tool_map
        history = AbstractMessage[PT.AIToolRequest(tool_calls = [ToolMessage(;
            tool_call_id = "1", raw = "{}",
            name = "func1", args = Dict())])]

        result = handle_tool_calls!(agent, history, session)
        @test length(result.history) == 2
        @test length(session.artifacts) == 1
        @test session.artifacts[end] === nothing

        # Test struct with output property
        history = AbstractMessage[PT.AIToolRequest(tool_calls = [ToolMessage(;
            tool_call_id = "2", raw = "{}",
            name = "struct_tool", args = Dict())])]

        result = handle_tool_calls!(agent, history, session)
        @test result.history[end].content == "struct output"
        @test session.artifacts[end] isa TestStructWithOutput

        # Test struct without output property (uses show)
        history = AbstractMessage[PT.AIToolRequest(tool_calls = [ToolMessage(;
            tool_call_id = "3", raw = "{}",
            name = "custom_tool", args = Dict())])]

        result = handle_tool_calls!(agent, history, session)
        @test occursin("custom value", result.history[end].content)
        @test occursin("TestStructNoOutput", result.history[end].content)

        # Test non-existent tool returns ToolNotFoundError
        history = AbstractMessage[PT.AIToolRequest(tool_calls = [ToolMessage(;
            tool_call_id = "4", raw = "{}",
            name = "nonexistent_tool", args = Dict())])]

        result = handle_tool_calls!(agent, history, session)
        @test length(result.history) == 2
        @test length(session.artifacts) == 4  # All previous artifacts + new one
        @test session.artifacts[end] isa PT.ToolNotFoundError
        @test string(session.artifacts[end]) == "PromptingTools.ToolNotFoundError(\"Tool `nonexistent_tool` not found\")"
        @test occursin("Tool `nonexistent_tool` not found", result.history[end].content)

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
        add_rules!(session_with_io, FixedOrder(Tool(func5)))
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
        tool1 = Tool(func1)
        add_tools!(agent, tool1)
        messages = AbstractMessage[PT.UserMessage("Hello")]

        # Test with both agent tools and session rules
        session = Session(agent)
        tool5 = Tool(func5)
        add_rules!(session, FixedOrder(tool5))

        # Test with tools verification using a mock function
        global tools_passed = Tool[]  # Use global to ensure tools_passed is accessible
        original_aitools = PT.aitools  # Store the original function
        mock_aitools = function(args...; kwargs...)
            global tools_passed = Vector{Tool}(kwargs[:tools])  # Convert to Vector{Tool} explicitly
            original_aitools(args...; kwargs...)
        end

        # Use let block for local scope
        let
            response = run_full_turn(agent, messages, session; max_turns = 1, aitools_override=mock_aitools)
            @test response isa Response
            @test !isempty(response.messages)
            @test response.messages[end].name == "func1"
            @test length(session.artifacts) == 1
            # Verify we're passing Tool objects
            @test all(t -> t isa Tool, tools_passed)
            @test tools_passed[1] === agent.tool_map["func1"]
        end

        # Test with custom io
        io = IOBuffer()
        session_with_io = Session(agent; io=io)
        add_rules!(session_with_io, FixedOrder(tool5))
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
        add_rules!(session2, FixedOrder(tool5))

        response = run_full_turn(agent2, messages, session2; max_turns = 1)
        @test response isa Response
        @test !isempty(response.messages)
        @test response.messages[end].name == "func5"
        @test length(session2.artifacts) == 1
        @test session2.artifacts[end] isa PT.ToolNotFoundError
        @test string(session2.artifacts[end]) == "PromptingTools.ToolNotFoundError(\"Tool `func5` not found\")"
    end

    @testset "run_full_turn termination and tool filtering" begin
        # Setup mock response for repeated tool calls
        response3 = Dict(
            :id => "125",
            :choices => [
                Dict(
                :message => Dict(:content => "test",
                    :tool_calls => [
                        Dict(:id => "125",
                        :function => Dict(
                            :name => "func1",
                            :arguments => JSON3.write(Dict())))
                    ]),
                :finish_reason => "tool_calls")
            ],
            :usage => Dict(:total_tokens => 20, :prompt_tokens => 15, :completion_tokens => 5)
        )
        schema = TestEchoOpenAISchema(; response = response3, status = 200)
        PT.register_model!(; name = "mocktools3", schema)

        agent = Agent(
            name = "TestAgent3", instructions = "You are a test agent.", model = "mocktools3")
        add_tools!(agent, Tool(func1))
        messages = AbstractMessage[PT.UserMessage("Hello")]

        # Test termination checks and tool filtering
        session = Session(agent)

        # Create different types of rules
        tool_rule = FixedOrder(order=["func1"])
        termination_rule = TerminationRepeatCheck(2)  # Terminate after 2 tool calls
        generic_rule = TerminationGenericCheck(callable=(h, a) -> length(h) > 5 ? nothing : a)

        # Add rules to session
        add_rules!(session, [tool_rule, termination_rule, generic_rule])

        # Test get_allowed_tools filtering
        all_tools = String[string(name) for name in keys(agent.tool_map)]
        allowed_tools = get_allowed_tools(session.rules, String[], all_tools)
        @test allowed_tools == ["func1"]  # Only tool rules should be processed
        @test length(allowed_tools) == 1  # Should only get tools from AbstractToolFlowRules

        # Run full turn with termination checks
        response = run_full_turn(agent, messages, session; max_turns = 5)
        @test response isa Response
        @test !isempty(response.messages)

        # Verify termination occurred after repeated tool usage
        tool_messages = filter(m -> m isa ToolMessage, response.messages)
        @test length(tool_messages) <= 2  # Should terminate after 2 uses due to TerminationRepeatCheck

        # Test termination with generic check
        session2 = Session(agent)
        add_rules!(session2, generic_rule)
        response2 = run_full_turn(agent, messages, session2; max_turns = 10)
        @test length(response2.messages) <= 6  # Should terminate when history length > 5

        # Test passthrough with no rules
        session3 = Session(agent)
        response3 = run_full_turn(agent, messages, session3; max_turns = 1)
        @test response3 isa Response
        @test !isempty(response3.messages)
        @test length(response3.messages) > 0

        # Test that non-tool rules are ignored in get_allowed_tools and combine behavior
        mixed_rules = [
            FixedOrder(order=["func1"]),
            TerminationRepeatCheck(2),
            FixedOrder(order=["func5", "func1"])  # Intentional duplicate of func1
        ]
        all_tools = ["func1", "func5"]

        # Test default combine (union) behavior
        allowed_tools_union = get_allowed_tools(mixed_rules, String[], all_tools)
        @test Set(allowed_tools_union) == Set(["func1", "func5"])  # Only tool rules processed, duplicates removed by design

        # Test vcat combine behavior (maintains order but deduplicates input tools)
        allowed_tools_vcat = get_allowed_tools(mixed_rules, String[], all_tools; combine=vcat)
        @test allowed_tools_vcat == ["func1", "func5"]  # Tools deduplicated before processing, order preserved

        # Test full turn with vcat combine
        session_vcat = Session(agent)
        add_rules!(session_vcat, mixed_rules)
        response_vcat = run_full_turn(agent, messages, session_vcat; max_turns=5, combine=vcat)
        @test response_vcat isa Response
        @test !isempty(response_vcat.messages)

        # Test passthrough with only non-tool rules
        non_tool_rules = [TerminationRepeatCheck(2), generic_rule]
        passthrough_tools = get_allowed_tools(non_tool_rules, String[], all_tools)
        @test passthrough_tools == all_tools  # Should passthrough when no tool rules present

    @testset "add_transfers!" begin
        # Initialize session first
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
        @test haskey(booking_agent.tool_map, "transfer_to_support_agent")
        @test haskey(booking_agent.tool_map, "transfer_to_sales_agent")
        @test haskey(support_agent.tool_map, "transfer_to_booking_agent")
        @test haskey(support_agent.tool_map, "transfer_to_sales_agent")
        @test haskey(sales_agent.tool_map, "transfer_to_booking_agent")
        @test haskey(sales_agent.tool_map, "transfer_to_support_agent")

        # Verify no self-transfer tools were created
        @test !haskey(booking_agent.tool_map, "transfer_to_booking_agent")
        @test !haskey(support_agent.tool_map, "transfer_to_support_agent")
        @test !haskey(sales_agent.tool_map, "transfer_to_sales_agent")

        # Test tool properties and docstrings
        support_transfer = booking_agent.tool_map["transfer_to_support_agent"]
        @test support_transfer.name == "transfer_to_support_agent"
        @test haskey(support_transfer.parameters, "handover_message")
        @test support_transfer.parameters["handover_message"]["type"] == "string"
        @test support_transfer.parameters["handover_message"]["required"] == true

        # Verify available agents are listed in docstring
        @test contains(support_transfer.description, "Support Agent")
        @test contains(support_transfer.description, "Sales Agent")
        @test contains(support_transfer.description, "Available agents for transfer from Booking Agent")
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

            # Get transfer tool and verify its structure
            transfer_tool = agent1.tool_map["transfer_to_agent_two"]
            @test transfer_tool isa Tool
            @test haskey(transfer_tool.parameters, "handover_message")

            # Test transfer function execution
            handover_msg = "Transferring to specialized agent for technical support"
            result = transfer_tool.callable(; handover_message=handover_msg)

            # Verify correct AgentRef is returned
            @test result isa AgentRef
            @test result.name == Symbol("Agent Two")
        end

        @testset "end-to-end agent transfers" begin
            session = Session()

            # Create agents with different specialties
            booking_agent = Agent(name="Booking Agent", instructions="Handle flight bookings")
            support_agent = Agent(name="Support Agent", instructions="Handle customer support")

            # Add agents to session
            session.agent_map[:booking] = booking_agent
            session.agent_map[:support] = support_agent

            # Add transfer tools
            add_transfers!(session)

            # Test complete transfer flow
            booking_to_support = booking_agent.tool_map["transfer_to_support_agent"]
            support_to_booking = support_agent.tool_map["transfer_to_booking_agent"]

            # Verify tool structure
            @test booking_to_support isa Tool
            @test haskey(booking_to_support.parameters, "handover_message")
            @test booking_to_support.parameters["handover_message"]["type"] == "string"
            @test booking_to_support.parameters["handover_message"]["required"] == true
            @test !isnothing(booking_to_support.description)
            @test contains(booking_to_support.description, "Available agents for transfer from Booking Agent")
            @test contains(booking_to_support.description, "Support Agent")

            # Transfer from booking to support
            handover_msg1 = "Customer needs help with existing booking"
            result1 = booking_to_support.callable(; handover_message=handover_msg1)

            # Verify first transfer
            @test result1 isa AgentRef
            @test result1.name == Symbol("Support Agent")

            # Transfer back to booking
            handover_msg2 = "Customer wants to modify their booking"
            result2 = support_to_booking.callable(; handover_message=handover_msg2)

            # Verify second transfer
            @test result2 isa AgentRef
            @test result2.name == Symbol("Booking Agent")
        end

        @testset "generic transfer_agent function" begin
            # Test direct usage of transfer_agent
            result = transfer_agent("Test Agent", "Testing transfer")
            @test result isa AgentRef
            @test result.name == Symbol("Test Agent")

            # Test function introspection
            arg_names = PT.get_arg_names(transfer_agent)
            arg_types = PT.get_arg_types(transfer_agent)

            @test length(arg_names) == 2
            @test arg_names[1] == :target_agent_name
            @test arg_names[2] == :handover_message

            @test length(arg_types) == 2
            @test arg_types[1] == String
            @test arg_types[2] == String

            # Test error handling
            @test_throws MethodError transfer_agent(Symbol("Test Agent"), "Testing transfer")
            @test_throws MethodError transfer_agent("Test Agent", 123)
        end
    end

    @testset "get_used_tools behavior" begin
        # Test extraction from AIToolRequests only
        history = AbstractMessage[]

        # Add AIToolRequest with multiple tool calls (including duplicates)
        push!(history, PT.AIToolRequest(tool_calls = [
            ToolMessage(tool_call_id="1", raw="{}", name="tool_a", args=Dict()),
            ToolMessage(tool_call_id="2", raw="{}", name="tool_a", args=Dict())
        ]))

        # Add another AIToolRequest
        push!(history, PT.AIToolRequest(tool_calls = [
            ToolMessage(tool_call_id="3", raw="{}", name="tool_b", args=Dict())
        ]))

        # Add a regular ToolMessage (should be ignored)
        push!(history, ToolMessage(tool_call_id="4", raw="{}", name="tool_c", args=Dict()))

        # Add another AIToolRequest with duplicate tool
        push!(history, PT.AIToolRequest(tool_calls = [
            ToolMessage(tool_call_id="5", raw="{}", name="tool_a", args=Dict())
        ]))

        # Test that get_used_tools only looks at AIToolRequests and preserves order with duplicates
        used_tools = get_used_tools(history)
        @test used_tools == ["tool_a", "tool_a", "tool_b", "tool_a"]  # Order preserved, duplicates maintained

        # Test that direct ToolMessages are ignored
        @test !in("tool_c", used_tools)

        # Test empty history
        @test isempty(get_used_tools(AbstractMessage[]))

        # Test history with only non-AIToolRequest messages
        mixed_history = [
            PT.UserMessage("test"),
            ToolMessage(tool_call_id="1", raw="{}", name="tool_d", args=Dict()),
            PT.AIMessage("test")
        ]
        @test isempty(get_used_tools(mixed_history))
    end
end
