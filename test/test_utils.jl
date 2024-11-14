using SwarmAgents: Agent, Tool, add_tools!, handle_tool_calls!, update_system_message!,
                   run_full_turn, run_full_turn!, Session, Response
using PromptingTools: AbstractMessage, UserMessage, SystemMessage, AIToolRequest,
                      ToolMessage, TestEchoOpenAISchema

func1() = nothing
func5() = "test"

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
    # Create a new history with tool calls for this test
    test_history = AbstractMessage[PT.AIToolRequest(
        content="Testing tool execution",  # Add content for assistant message
        tool_calls = [ToolMessage(
            content=nothing,  # Explicitly set content to nothing for tool request
            raw="{}",
            tool_call_id="test",
            name="func5",
            args=Dict{Symbol,Any}())])]
    # Use session_with_io.agent to ensure consistent agent context
    result_io = handle_tool_calls!(session_with_io.agent, test_history, session_with_io)
    output = String(take!(io))
    println("Debug - Output captured: ", output)  # Debug print
    @test contains(output, "Tool Request") || contains(output, "Tool Output")  # Verify either request or output was captured
end

# Test update_system_message!
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
@testset "run_full_turn,run_full_turn!" begin
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
    @test length(session.artifacts) == 1  # Verify artifacts collection

    # Test with custom io
    io = IOBuffer()
    session_with_io = Session(agent; io=io)
    add_rules!(session_with_io, Tool(func5))
    updated_session = run_full_turn!(session_with_io, "Hello")
    @test length(updated_session.messages) > 1
    @test updated_session.agent === agent
    @test updated_session.messages[end].name == "func1"
    output = String(take!(io))
    @test !isempty(output)  # Verify output was captured in buffer

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
    @test session2.artifacts[end] == "test"  # func5 returns "test"
end

@testset "Session constructor" begin
    agent = Agent(name = "TestAgent")
    context = Dict{Symbol, Any}(:test => true)
    session = Session(agent; context = context)

    @test session.agent === agent
    @test session.context == context
    @test isempty(session.messages)
end
