using Swarm: Agent, Session, Response, scrub_agent_name, update_model, add_tools!, Tool

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