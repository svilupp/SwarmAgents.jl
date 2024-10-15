
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

Base.@kwdef struct Response
    messages::Vector = PT.AbstractChatMessage[]
    agent::Union{Agent, Nothing} = nothing
    context_variables::Dict = Dict()
end

"""
Encapsulates the possible return values for an agent function.

Attributes:
    value (str): The result value as a string.
    agent (Agent): The agent instance, if applicable.
    context_variables (dict): A dictionary of context variables.
"""
Base.@kwdef struct Result
    value::String = ""
    agent::Union{Agent, Nothing} = nothing
    context_variables::Dict = Dict()
end