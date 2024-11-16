using SwarmAgents
using PromptingTools
const PT = PromptingTools
using Test

@testset "Privacy Features" begin
    @testset "PrivateMessage" begin
        # Test PrivateMessage creation and interface
        base_msg = PT.UserMessage("Test message")
        private_msg = PrivateMessage(base_msg, ["Agent1"])

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

    @testset "Tool Usage Tracking" begin
        # Note: Tool usage is tracked regardless of privacy settings
        # Privacy only affects message visibility for LLMs, not flow control or authentication state
        agent1 = Agent(name="Agent1", private=true)
        agent2 = Agent(name="Agent2")

        # Create history with tool messages, including authentication tool usage
        history = PT.AbstractMessage[
            PT.UserMessage("Start"),
            PrivateMessage(
                PT.AIToolRequest(tool_calls=[ToolMessage("output", nothing, "auth", "auth", Dict(), "auth", :default)]),
                ["Agent1"]
            ),
            PT.AIToolRequest(tool_calls=[ToolMessage("output", nothing, "public", "public", Dict(), "public", :default)]),
            PrivateMessage(
                PT.AIToolRequest(tool_calls=[ToolMessage("output", nothing, "private", "private", Dict(), "private", :default)]),
                ["Agent2"]
            )
        ]

        # Test get_used_tools ignores privacy settings (important for flow control and auth state)
        tools1 = get_used_tools(history, agent1)
        @test Set(tools1) == Set(["auth", "private", "public"])  # Should see all tools

        tools2 = get_used_tools(history, agent2)
        @test Set(tools2) == Set(["auth", "private", "public"])  # Should see all tools

        # Test get_used_tools without agent
        tools_all = get_used_tools(history)
        @test Set(tools_all) == Set(["auth", "private", "public"])  # Should see all tools

        # Verify that while tools are tracked, message visibility still respects privacy
        filtered_history = filter_history(history, agent1)
        @test length(filtered_history) == 3  # Should only see public messages and own private messages
        @test !any(msg -> msg isa PrivateMessage && "Agent2" in msg.visible, filtered_history)
    end

    @testset "Message Privacy Handling" begin
        agent = Agent(name="PrivateAgent", private=true)
        public_agent = Agent(name="PublicAgent", private=false)

        # Test privacy handling for private agent
        msg = PT.UserMessage("Test message")
        private_msg = maybe_private_message(msg, agent)
        @test private_msg isa PrivateMessage
        @test private_msg.visible == [agent.name]

        # Test no privacy wrapping for public agent
        public_msg = maybe_private_message(msg, public_agent)
        @test public_msg === msg  # Should return original message

        # Test last turn visibility
        last_turn_msg = maybe_private_message(msg, agent; last_turn=true)
        @test last_turn_msg isa PrivateMessage
        @test last_turn_msg.last_turn == true
        @test is_visible(last_turn_msg, Agent(name="OtherAgent", private=false))

        # Test assistant message with no tool calls visibility
        assistant_msg = PT.AIMessage("Final response")
        private_assistant = maybe_private_message(assistant_msg, agent; last_turn=true)
        @test is_visible(private_assistant, Agent(name="OtherAgent", private=false))

        # Test agent handoff visibility
        tool_request = PT.AIToolRequest(tool_calls=[ToolMessage("test", nothing, "id", "id", Dict{Symbol,Any}(), "test", :default)])
        handoff_msg = maybe_private_message(tool_request, agent; last_turn=true)
        @test is_visible(handoff_msg, Agent(name="NextAgent", private=true))
    end
end
