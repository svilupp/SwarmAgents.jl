
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
    name::String
    model::String = "gpt-4o"
    instructions::String = "You are a helpful agent."
    tool_map::Dict{String, AbstractTool} = Dict()
    tool_choice::Union{String, Nothing} = nothing
    parallel_tool_calls::Bool = true
end
function Base.show(io::IO, t::AbstractAgent)
    print(io, t.name, " (Tools: ", length(t.tool_map), ")")
end

Base.@kwdef mutable struct Session
    messages::Vector = PT.AbstractMessage[]
    agent::Union{Agent, Nothing} = nothing
    context::Dict{Symbol, Any} = Dict{Symbol, Any}()
end
function Base.show(io::IO, t::Session)
    agent_str = isnothing(t.agent) ? "None" : t.agent.name
    print(io, "Session (Messages: ", length(t.messages), ", Agent: ", agent_str, ")")
end

"Response from a single turn of an agent."
Base.@kwdef struct Response
    messages::Vector = PT.AbstractMessage[]
    agent::Union{Agent, Nothing} = nothing
    context::Dict{Symbol, Any} = Dict{Symbol, Any}()
end
Base.show(io::IO, t::Response) = dump(io, t; maxdepth = 1)