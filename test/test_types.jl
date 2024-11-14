using SwarmAgents: Agent, Session, Response, scrub_agent_name, update_model, add_tools!,
                   Tool, add_rules!

@testset "scrub_agent_name, update_model" begin
    agent = Agent(name = "Test Agent", model = "gpt-3.5-turbo")
    @test scrub_agent_name(agent) == "Test_Agent"

    agent = Agent(name = "Test Agent 2", model = "gpt-3.5-turbo")
    @test scrub_agent_name(agent) == "Test_Agent_2"

    agent = update_model(agent, "gpt-4")
    @test agent.model == "gpt-4"
end

func1() = nothing
func2() = nothing
func3() = nothing
func4() = nothing
@testset "add_tools!" begin
    # Test adding a vector of tools
    agent = Agent(name = "TestAgent")
    tools = [Tool(func1), Tool(func2)]
    add_tools!(agent, tools)
    @test length(agent.tool_map) == 2
    @test "func1" in keys(agent.tool_map)
    @test "func2" in keys(agent.tool_map)

    # Test adding a single AbstractTool
    new_tool = Tool(func3)
    add_tools!(agent, new_tool)
    @test length(agent.tool_map) == 3
    @test "func3" in keys(agent.tool_map)

    # Test adding a callable (Function)
    add_tools!(agent, func4)
    @test length(agent.tool_map) == 4
    @test "func4" in keys(agent.tool_map)

    # Test error on duplicate tool name
    @test_throws AssertionError add_tools!(agent, Tool(func1))
end

@testset "Session" begin
    # Test default initialization
    session = Session()
    @test isempty(session.messages)
    @test isnothing(session.agent)
    @test isempty(session.context)
    @test isempty(session.artifacts)
    @test session.io === stdout
    @test isempty(session.rules)

    # Test initialization with agent
    agent = Agent(name = "TestAgent")
    session = Session(agent)
    @test session.agent === agent

    # Test add_rules!
    tool1 = Tool(func1)
    tool2 = Tool(func2)
    tools = [tool1, tool2]

    # Test adding a vector of tools
    add_rules!(session, tools)
    @test length(session.rules) == 2
    @test "func1" in keys(session.rules)
    @test "func2" in keys(session.rules)

    # Test adding a single AbstractTool
    new_tool = Tool(func3)
    add_rules!(session, new_tool)
    @test length(session.rules) == 3
    @test "func3" in keys(session.rules)

    # Test adding a callable (Function)
    add_rules!(session, func4)
    @test length(session.rules) == 4
    @test "func4" in keys(session.rules)

    # Test error on duplicate rule name
    @test_throws AssertionError add_rules!(session, Tool(func1))
end

@testset "print_progress" begin
    using SwarmAgents: print_progress
    using PromptingTools: AIToolRequest, ToolMessage

    # Setup
    agent = Agent(name = "TestAgent")

    # Test with io = nothing
    io = nothing
    msg = AIToolRequest("content", Vector{ToolMessage}(), "test", nothing, (1,1), 0.0, nothing, nothing, nothing, nothing, nothing, nothing, :default)
    @test isnothing(print_progress(io, agent, msg))

    # Test with StringIO to capture output
    io = IOBuffer()

    # Test AIToolRequest with content
    msg = AIToolRequest("content", Vector{ToolMessage}(), "test", nothing, (1,1), 0.0, nothing, nothing, nothing, nothing, nothing, nothing, :default)
    print_progress(io, agent, msg)
    output = String(take!(io))
    @test contains(output, "Assistant (TestAgent): content")
    @test contains(output, ">>")

    # Test ToolMessage without content
    msg = ToolMessage(nothing, nothing, "test_tool", "test_tool", Dict{Symbol,Any}(:arg1 => "value1"), nothing, :default)
    print_progress(io, agent, msg)
    output = String(take!(io))
    @test contains(output, "Tool Request: test_tool")
    @test contains(output, "args: ")
    @test contains(output, "arg1")

    # Test ToolMessage with content
    msg = ToolMessage("output", nothing, "test_tool", "test_tool", Dict{Symbol,Any}(), nothing, :default)
    print_progress(io, agent, msg)
    output = String(take!(io))
    @test contains(output, "Tool Output: output")
end
