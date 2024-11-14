using Test
using SwarmAgents: Agent, Tool, FixedOrder, FixedPrerequisites, get_allowed_tools, get_used_tools, add_rules!
const PT = PromptingTools

@testset "Flow Rules" begin
    # Test FixedOrder rule
    @testset "FixedOrder" begin
        rule = FixedOrder([:setup, :process, :finish])

        # Initially only first tool available
        @test get_allowed_tools(rule, Symbol[]) == ["setup"]

        # After setup, only process available
        @test get_allowed_tools(rule, [:setup]) == ["process"]

        # After process, only finish available
        @test get_allowed_tools(rule, [:setup, :process]) == ["finish"]

        # After all tools used, nothing available
        @test isempty(get_allowed_tools(rule, [:setup, :process, :finish]))
    end

    # Test FixedPrerequisites rule
    @testset "FixedPrerequisites" begin
        rule = FixedPrerequisites([:prepare, :analyze, :report])

        # Initially only first tool available
        @test get_allowed_tools(rule, Symbol[]) == ["prepare"]

        # After prepare, both prepare and analyze available
        @test Set(get_allowed_tools(rule, [:prepare])) == Set(["prepare", "analyze"])

        # After both prepare and analyze, all tools available
        @test Set(get_allowed_tools(rule, [:prepare, :analyze])) == Set(["prepare", "analyze", "report"])
    end

    # Test combining multiple rules
    @testset "Combining Rules" begin
        order_rule = FixedOrder([:load, :clean, :analyze])
        prereq_rule = FixedPrerequisites([:load, :clean, :analyze])

        # Test intersect (default)
        @test get_allowed_tools([order_rule, prereq_rule], [:load]) == ["clean"]

        # Test union
        used_tools = [:load, :clean]
        allowed = Set(get_allowed_tools([order_rule, prereq_rule], used_tools, combine=union))
        @test allowed == Set(["analyze", "clean"])
    end

    # Test get_used_tools
    @testset "get_used_tools" begin
        history = [
            PT.AIToolRequest(tool_calls=[PT.ToolMessage(name="setup", tool_call_id="1", raw="")]),
            PT.AIToolRequest(tool_calls=[PT.ToolMessage(name="process", tool_call_id="2", raw="")])
        ]
        @test Set(get_used_tools(history)) == Set([:setup, :process])
    end
end
