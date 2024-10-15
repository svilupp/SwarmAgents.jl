function add_tools!(agent::Agent, tools::Vector)
    for tool in tools
        add_tools!(agent, tool)
    end
end
function add_tools!(agent::Agent, tool::AbstractTool)
    @assert tool.name∉keys(agent.tool_map) "Tool $(tool.name) already exists. Only unique tool names are allowed."
    agent.tool_map[tool.name] = tool
end
function add_tools!(agent::Agent, callable::Union{Function, Type, Method})
    add_tools!(agent, Tool(callable))
end
