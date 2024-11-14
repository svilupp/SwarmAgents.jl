using Test
using SwarmAgents

@testset "SwarmAgents Module" begin
    # Test that all exported types are available
    @test isdefined(SwarmAgents, :Agent)
    @test isdefined(SwarmAgents, :Session)
    @test isdefined(SwarmAgents, :Response)
    @test isdefined(SwarmAgents, :isabstractagent)

    # Test that all exported functions are available
    @test isdefined(SwarmAgents, :add_tools!)
    @test isdefined(SwarmAgents, :run_full_turn!)
    @test isdefined(SwarmAgents, :run_full_turn)

    # Test basic module functionality
    agent = Agent(name="TestAgent")
    session = Session(agent)
    @test session.agent === agent
end
