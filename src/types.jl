
abstract type AbstractAgent end
isabstractagent(x) = x isa AbstractAgent

"""
    Agent

Agent is a stateless struct that holds the the reference to LLM, tools and the instructions.

# Fields
- `name::String`: The name of the agent.
- `model::String`: The model to use for the agent.
- `instructions::String`: The instructions for the agent.
- `tool_map::Dict{String, AbstractTool}`: A dictionary of tools available to the agent.
- `tool_choice::Union{String, Nothing}`: The tool choice for the agent.
- `parallel_tool_calls::Bool`: Whether to allow parallel tool calls. Defaults to `true` - NOT SUPPORTED YET.
"""
Base.@kwdef struct Agent <: AbstractAgent
    name::String = "Agent"
    model::String = "gpt-4o"
    instructions::String = "You are a helpful agent."
    tool_map::Dict{String, AbstractTool} = Dict()
    tool_choice::Union{String, Nothing} = nothing
    parallel_tool_calls::Bool = true
end
function Base.show(io::IO, t::AbstractAgent)
    print(io, t.name, " (Tools: ", length(t.tool_map), ")")
end

scrub_agent_name(agent::Agent) = replace(agent.name, " " => "_")
function update_model(agent::Agent, model::String)
    return Agent(; [f => getfield(agent, f) for f in fieldnames(Agent)]..., model)
end

"""
    Session

Session is a mutable struct that holds the `messages`, `agent` and `context`.

# Fields
- `messages::Vector{PT.AbstractMessage}`: The history of chat or tool messages in the session.
- `agent::Union{Agent, Nothing}`: The current active agent in the session.
- `context::Dict{Symbol, Any}`: The context variables or other data in the session.
"""
Base.@kwdef mutable struct Session
    messages::Vector = PT.AbstractMessage[]
    agent::Union{Agent, Nothing} = nothing
    context::Dict{Symbol, Any} = Dict{Symbol, Any}()
end
function Base.show(io::IO, t::Session)
    agent_str = isnothing(t.agent) ? "None" : t.agent.name
    print(io, "Session (Messages: ", length(t.messages), ", Agent: ", agent_str, ")")
end

"""
    Response

Response from a single full turn of swarm.

# Fields
- `messages::Vector{PT.AbstractMessage}`: The additional messages from the last full turn.
- `agent::Union{Agent, Nothing}`: The current active agent in the session.
- `context::Dict{Symbol, Any}`: The context variables or other data in the session.
"""
Base.@kwdef struct Response
    messages::Vector = PT.AbstractMessage[]
    agent::Union{Agent, Nothing} = nothing
    context::Dict{Symbol, Any} = Dict{Symbol, Any}()
end
Base.show(io::IO, t::Response) = dump(io, t; maxdepth = 1)

### Tools
"""
    add_tools!(agent::Agent, tools::Vector)

Adds `tools` to an `agent`.
"""
function add_tools!(agent::Agent, tools::Vector; kwargs...)
    for tool in tools
        add_tools!(agent, tool; kwargs...)
    end
end
function add_tools!(agent::Agent, tool::AbstractTool; kwargs...)
    @assert tool.name∉keys(agent.tool_map) "Tool $(tool.name) already exists. Only unique tool names are allowed."
    agent.tool_map[tool.name] = tool
end
function add_tools!(agent::Agent, callable::Union{Function, Type, Method}; kwargs...)
    add_tools!(agent, Tool(callable; kwargs...))
end