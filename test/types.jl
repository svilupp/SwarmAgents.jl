using Swarm: Agent, Session, Response, scrub_agent_name, update_model, add_tools!, Tool

@testset "scrub_agent_name, update_model" begin
    agent = Agent(name = "Test Agent", model = "gpt-3.5-turbo")
    @test scrub_agent_name(agent) == "Test_Agent"

    agent.name = "Test Agent 2"
    @test scrub_agent_name(agent) == "Test_Agent_2"

    agent = update_model(agent, "gpt-4")
    @test agent.model == "gpt-4"
end

@testset "add_tools!" begin
    # Test adding a vector of tools
    agent = Agent(name = "TestAgent")
    tools = [Tool(identity), Tool(println)]
    add_tools!(agent, tools)
    @test length(agent.tool_map) == 2
    @test "identity" in keys(agent.tool_map)
    @test "println" in keys(agent.tool_map)

    # Test adding a single AbstractTool
    new_tool = Tool(sum)
    add_tools!(agent, new_tool)
    @test length(agent.tool_map) == 3
    @test "sum" in keys(agent.tool_map)

    # Test adding a callable (Function)
    add_tools!(agent, abs)
    @test length(agent.tool_map) == 4
    @test "abs" in keys(agent.tool_map)

    # Test error on duplicate tool name
    @test_throws AssertionError add_tools!(agent, Tool(identity))
end