using Test
using SwarmAgents
using PromptingTools
using PromptingTools: UserMessage
import Base.Logging

@testset "Agent Utils" begin
    @testset "Agent Type Checks" begin
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

    @testset "Session Integration" begin
        session = Session()
        agent = Agent(name="MainAgent")
        ref = AgentRef(name="MainAgent")

        # Add agent to session
        add_agent!(session, agent)

        # Test run_full_turn with reference
        messages = [UserMessage("Test message")]
        response = run_full_turn(ref, messages, session)

        @test response.agent === agent
    end
end
