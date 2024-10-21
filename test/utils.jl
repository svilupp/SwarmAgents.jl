using Swarm: Agent, Tool, add_tools!, handle_tool_calls!, update_system_message!,
             run_full_turn, run_full_turn!, Session, Response
using PromptingTools: AbstractMessage, UserMessage, SystemMessage, AIToolRequest,
                      ToolMessage

func1() = nothing
func5() = "test"

@testset "handle_tool_calls!" begin
    agent = Agent(name = "TestAgent")
    add_tools!(agent, [Tool(func1), Tool(func5)])
    history = AbstractMessage[PT.AIToolRequest(tool_calls = [ToolMessage(;
        tool_call_id = "1", raw = "",
        name = "func5", args = Dict())])]
    context = Dict{Symbol, Any}()

    result = handle_tool_calls!(agent, history, context)
    @test length(result.history) == 2
    @test result.history[end].content == "test"

    # Test with no active agent
    push!(history, PT.AIToolRequest(; content = "Hi"))
    result_no_agent = handle_tool_calls!(nothing, history, context)
    @test result_no_agent.active_agent === nothing

    # Test with empty tool calls
    empty_history = AbstractMessage[PT.AIToolRequest(;
        content = "hi", tool_calls = ToolMessage[])]
    result_empty = handle_tool_calls!(agent, empty_history, context)
    @test length(result_empty.history) == 1
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
# Test run_full_turn and run_full_turn!
@testset "run_full_turn and run_full_turn!" begin
    agent = Agent(name = "TestAgent", instructions = "You are a test agent.")
    add_tools!(agent, Tool(identity))
    messages = AbstractMessage[PT.UserMessage("Hello")]
    context = Dict{Symbol, Any}()

    response = run_full_turn(agent, messages, context)
    @test response isa Response
    @test !isempty(response.messages)

    session = Session(agent)
    updated_session = run_full_turn!(session, "Hello")
    @test length(updated_session.messages) > 1
    @test updated_session.agent === agent
end

@testset "Session constructor" begin
    agent = Agent(name = "TestAgent")
    context = Dict{Symbol, Any}(:test => true)
    session = Session(agent; context = context)

    @test session.agent === agent
    @test session.context == context
    @test isempty(session.messages)
end
