using Test
using SwarmAgents
using PromptingTools
using PromptingTools: ToolMessage, UserMessage, AIMessage, Tool, ToolNotFoundError

@testset "Tool Error Handling" begin
    @testset "ToolNotFoundError" begin
        # Create a session with a minimal agent
        session = Session()
        agent = Agent(name="TestAgent")
        tool_a = Tool(name="tool_a", parameters=Dict(), description="Test tool A", strict=false, callable=identity)
        add_tools!(agent, tool_a)
        session.agent = agent

        # Create a tool message for a non-existent tool
        nonexistent_tool = ToolMessage(
            "",  # content
            1,   # index
            "test_id",  # tool_call_id
            "test_conv",  # req_id
            Dict(),  # args
            "nonexistent_tool",  # name
            :default  # _type
        )

        # Test that execute_tool throws ToolNotFoundError
        @test_throws ToolNotFoundError PT.execute_tool(agent.tool_map, nonexistent_tool, session.context)
    end
end
