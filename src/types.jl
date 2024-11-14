
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
- `private::Bool`: Whether agent's messages should be private by default.
"""
Base.@kwdef struct Agent <: AbstractAgent
    name::String = "Agent"
    model::String = "gpt-4o"
    instructions::String = "You are a helpful agent."
    tool_map::Dict{String, AbstractTool} = Dict()
    tool_choice::Union{String, Nothing} = nothing
    parallel_tool_calls::Bool = true
    private::Bool = false  # Whether agent's messages should be private by default
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
- `artifacts::Vector{Any}`: Collects all tool outputs in their full extent.
- `io::Union{Nothing,IO}`: The sink for printing the outputs.
- `rules::Dict{String, AbstractTool}`: The rules for the session.
"""
Base.@kwdef mutable struct Session
    messages::Vector = PT.AbstractMessage[]
    agent::Union{Agent, Nothing} = nothing
    context::Dict{Symbol, Any} = Dict{Symbol, Any}()
    artifacts::Vector{Any} = Any[]
    io::Union{Nothing,IO} = stdout
    rules::Dict{String, AbstractTool} = Dict{String, AbstractTool}()
end

Session(agent::Agent; io::Union{Nothing,IO}=stdout, context::Dict{Symbol,Any}=Dict{Symbol,Any}()) =
    Session(PT.AbstractMessage[], agent, context, Any[], io, Dict{String,AbstractTool}())

function Base.show(io::IO, t::Session)
    agent_str = isnothing(t.agent) ? "None" : t.agent.name
    print(io, "Session (Messages: ", length(t.messages), ", Agent: ", agent_str, ")")
end

"""
    print_progress(io::Union{IO,Nothing}, agent::Union{AbstractAgent, Nothing}, message; kwargs...)

Print progress messages based on message type. If io is Nothing, no output is produced.
Handles different message types:
- AIToolRequest with content: prints assistant message
- ToolMessage without content: prints tool request name and args
- ToolMessage with content: prints tool output
"""
function print_progress(io::Nothing, agent::Union{AbstractAgent, Nothing}, message; kwargs...)
    return nothing
end

function print_progress(io::IO, agent::Union{AbstractAgent, Nothing}, message; kwargs...)
    if PT.isaitoolrequest(message)
        name_assistant = "Assistant ($(isnothing(agent) ? "None" : scrub_agent_name(agent)))"
        printstyled(io, "$(name_assistant): $(message.content)\n>> ", color = :magenta)
    elseif PT.istoolmessage(message)
        if !isnothing(message.content)
            # For tool outputs (with content), print the output
            printstyled(io, "Tool Output: $(message.content)\n", color = :light_blue)
        else
            # For tool requests (no content), print the tool name and args
            tool_id = isnothing(message.tool_call_id) ? message.name : message.tool_call_id
            printstyled(io, "Tool Request: $(tool_id)\nargs: ", color = :light_blue)
            if !isempty(message.args)
                for (k, v) in message.args
                    printstyled(io, "$(k)=$(v) ", color = :light_blue)
                end
            end
            println(io)
        end
    end
    println(io)  # Add extra newline for better readability
    flush(io)
end

"""
    add_rules!(session::Session, tools::Vector)

Adds tools to the session's rules.
"""
function add_rules!(session::Session, tools::Vector; kwargs...)
    for tool in tools
        add_rules!(session, tool; kwargs...)
    end
end

function add_rules!(session::Session, tool::AbstractTool; kwargs...)
    @assert tool.name∉keys(session.rules) "Rule $(tool.name) already exists. Only unique rule names are allowed."
    session.rules[tool.name] = tool
end

function add_rules!(session::Session, callable::Union{Function, Type, Method}; kwargs...)
    add_rules!(session, Tool(callable; kwargs...))
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
