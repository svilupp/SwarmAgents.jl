using SwarmAgents
using PromptingTools
const PT = PromptingTools
using Test

@testset "Privacy Features" begin
    @testset "PrivateMessage" begin
        # Test PrivateMessage creation and interface
        base_msg = PT.UserMessage("Test message")
        private_msg = PrivateMessage(base_msg, ["Agent1"])

        @test PT.content(private_msg) == "Test message"
        @test PT.role(private_msg) == PT.role(base_msg)
        @test PT.name(private_msg) == PT.name(base_msg)
        @test PT.tool_calls(private_msg) == PT.tool_calls(base_msg)
    end

    @testset "Agent Privacy" begin
        # Test private agent creation
        private_agent = Agent(name="PrivateAgent", private=true)
        public_agent = Agent(name="PublicAgent", private=false)

        @test private_agent.private == true
        @test public_agent.private == false
    end

    @testset "Message Visibility" begin
        agent1 = Agent(name="Agent1", private=true)
        agent2 = Agent(name="Agent2", private=false)

        # Test regular message visibility
        public_msg = PT.UserMessage("Public message")
        @test is_visible(public_msg, agent1) == true
        @test is_visible(public_msg, agent2) == true

        # Test private message visibility
        private_msg = PrivateMessage(PT.UserMessage("Private message"), ["Agent1"])
        @test is_visible(private_msg, agent1) == true
        @test is_visible(private_msg, agent2) == false
    end

    @testset "History Filtering" begin
        agent1 = Agent(name="Agent1")
        agent2 = Agent(name="Agent2")

        # Create mixed history
        history = PT.AbstractMessage[
            PT.UserMessage("Public message 1"),
            PrivateMessage(PT.UserMessage("Private for Agent1"), ["Agent1"]),
            PT.UserMessage("Public message 2"),
            PrivateMessage(PT.UserMessage("Private for Agent2"), ["Agent2"])
        ]

        # Test filtering for Agent1
        filtered_history1 = filter_history(history, agent1)
        @test length(filtered_history1) == 3  # Should see public messages and own private message
        @test any(msg -> msg isa PrivateMessage && "Agent1" in msg.visible, filtered_history1)

        # Test filtering for Agent2
        filtered_history2 = filter_history(history, agent2)
        @test length(filtered_history2) == 3  # Should see public messages and own private message
        @test any(msg -> msg isa PrivateMessage && "Agent2" in msg.visible, filtered_history2)
    end

    @testset "Tool Usage Privacy" begin
        agent1 = Agent(name="Agent1", private=true)
        agent2 = Agent(name="Agent2")

        # Create history with tool messages
        history = PT.AbstractMessage[
            PT.UserMessage("Start"),
            PrivateMessage(
                ToolMessage("output", nothing, "tool1", "tool1", Dict(), "tool1", :default),
                ["Agent1"]
            ),
            ToolMessage("output", nothing, "tool2", "tool2", Dict(), "tool2", :default),
            PrivateMessage(
                ToolMessage("output", nothing, "tool3", "tool3", Dict(), "tool3", :default),
                ["Agent2"]
            )
        ]

        # Test get_used_tools for different agents
        tools1 = get_used_tools(history, agent1)
        @test :tool1 in tools1  # Should see own private tool
        @test :tool2 in tools1  # Should see public tool
        @test !(:tool3 in tools1)  # Should not see Agent2's private tool

        tools2 = get_used_tools(history, agent2)
        @test !(:tool1 in tools2)  # Should not see Agent1's private tool
        @test :tool2 in tools2  # Should see public tool
        @test :tool3 in tools2  # Should see own private tool
    end

    @testset "Message Wrapping" begin
        agent = Agent(name="PrivateAgent", private=true)
        public_agent = Agent(name="PublicAgent", private=false)

        # Test wrapping for private agent
        msg = PT.UserMessage("Test message")
        wrapped = wrap_message(msg, agent)
        @test wrapped isa PrivateMessage
        @test wrapped.visible == [agent.name]

        # Test no wrapping for public agent
        public_wrapped = wrap_message(msg, public_agent)
        @test public_wrapped === msg  # Should return original message
    end
end
