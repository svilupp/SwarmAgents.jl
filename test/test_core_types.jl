using Test
using SwarmAgents
using PromptingTools
using PromptingTools: UserMessage, AIMessage, ToolMessage, Tool
using SwarmAgents: ToolFlowRules
import Base.Logging

# Define test utility functions at module level
func1() = nothing
func2() = nothing

@testset "Core Types" begin
    @testset "Agent Type Hierarchy" begin
        # Create test agents and references
        agent = Agent(name="TestAgent")
        agent_ref = AgentRef(name="TestAgent")

        # Test type checks
        @test isabstractagent(agent)
        @test isabstractagent(agent_ref)
        @test isabstractagentactor(agent)
        @test !isabstractagentactor(agent_ref)
        @test isabstractagentref(agent_ref)
        @test !isabstractagentref(agent)
    end

    @testset "Agent Configuration" begin
        agent = Agent(name = "Test Agent", model = "gpt-3.5-turbo")

        # Test basic agent configuration
        @test agent.name == "Test Agent"
        @test agent.model == "gpt-3.5-turbo"
        @test isempty(agent.tool_map)
        @test !agent.private

        # Test tool management
        tools = [Tool(func1), Tool(func2)]
        add_tools!(agent, tools)
        @test length(agent.tool_map) == 2
        @test "func1" in keys(agent.tool_map)
        @test "func2" in keys(agent.tool_map)

        # Test error on duplicate tool
        @test_throws AssertionError add_tools!(agent, Tool(func1))
    end

    @testset "Agent Map Management" begin
        session = Session()
        agent1 = Agent(name="Agent1")
        agent2 = Agent(name="Agent1")  # Create agent2 with same name as agent1
        ref1 = AgentRef(name="Agent1")

        # Test add_agent!
        add_agent!(session, agent1)
        @test haskey(session.agent_map, Symbol("Agent1"))
        @test session.agent_map[Symbol("Agent1")] === agent1

        # Test overwrite warning and behavior
        @test_logs (:warn, "Overwriting existing agent 'Agent1' in agent map") begin
            add_agent!(session, agent2)
        end

        # Verify agent2 replaced agent1
        @test session.agent_map[Symbol("Agent1")] === agent2
        @test find_agent(session.agent_map, ref1) === agent2

        # Test nested references
        ref2 = AgentRef(name="Ref2")
        ref3 = AgentRef(name="Ref3")
        add_agent!(session, ref2)
        add_agent!(session, ref3)
        session.agent_map[Symbol("Ref2")] = ref3
        session.agent_map[Symbol("Ref3")] = agent1

        @test find_agent(session.agent_map, ref2) === agent1

        # Test error cases
        @test_throws ArgumentError find_agent(session.agent_map, AgentRef(name="NonExistent"))
    end

    @testset "Session Management" begin
        # Test default initialization
        session = Session()
        @test isempty(session.messages)
        @test isnothing(session.agent)
        @test isempty(session.context)
        @test isempty(session.artifacts)
        @test session.io === stdout
        @test isempty(session.rules)
        @test isempty(session.agent_map)

        # Test initialization with agent
        agent = Agent(name = "TestAgent")
        session = Session(agent)
        @test session.agent === agent

        # Test session rules management
        flow_rules = [ToolFlowRules(Tool(func1)), ToolFlowRules(Tool(func2))]

        add_rules!(session, flow_rules)
        @test length(session.rules) == 2
        @test haskey(session.rules, "func1")
        @test haskey(session.rules, "func2")
        @test session.rules["func1"] isa ToolFlowRules
        @test session.rules["func2"] isa ToolFlowRules

        # Test error on duplicate rule
        @test_logs (:warn, "Overwriting existing rule 'func1' in session rules") add_rules!(session, ToolFlowRules(Tool(func1)))
    end
end
