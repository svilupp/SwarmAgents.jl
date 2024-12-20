# Core types for SwarmAgents.jl

"""
Core type implementations for SwarmAgents.

This file contains concrete type implementations and their associated functions.
Abstract types are defined in abstract_types.jl
"""

# Agent reference implementation
"""
    AgentRef <: AbstractAgentRef

A reference to another agent in the system.

# Fields
- `name::String`: The name of the referenced agent
"""
Base.@kwdef struct AgentRef <: AbstractAgentRef
    name::Symbol
end

# Provide String constructor for convenience
AgentRef(name::String) = AgentRef(name=Symbol(name))

"""
    Response

Container for the results of a workflow operation.

# Fields
- `messages::Vector{<:PT.AbstractMessage}`: New messages generated during the operation
- `agent::Union{AbstractAgent, Nothing}`: The resulting agent state
- `context::Dict{Symbol, Any}`: The resulting context state
- `tools_used::Vector{AbstractTool}`: Tools used during the operation
"""
Base.@kwdef struct Response
    messages::Vector{<:PT.AbstractMessage} = PT.AbstractMessage[]
    agent::Union{AbstractAgent, Nothing} = nothing
    context::Dict{Symbol, Any} = Dict{Symbol, Any}()
    tools_used::Vector{AbstractTool} = AbstractTool[]
end

"""
    Agent <: AbstractAgentActor

A concrete agent implementation that can perform actions.

# Fields
- `name::String`: The name of the agent
- `model::String`: The model to use for the agent
- `instructions::String`: The instructions for the agent
- `tool_map::Dict{String, AbstractTool}`: A dictionary of tools available to the agent
- `tool_choice::Union{String, Nothing}`: The tool choice for the agent
- `parallel_tool_calls::Bool`: Whether to allow parallel tool calls
- `private::Bool`: Whether agent's messages should be private by default
"""
Base.@kwdef struct Agent <: AbstractAgentActor
    name::String = "Agent"
    model::String = "gpt-4"
    instructions::String = "You are a helpful agent."
    tool_map::Dict{String, AbstractTool} = Dict()
    tool_choice::Union{String, Nothing} = nothing
    parallel_tool_calls::Bool = true
    private::Bool = false
end

"""
    Session

Main container for managing agent interactions and state.

# Fields
- `messages::Vector{<:PT.AbstractMessage}`: Message history
- `agent::Union{AbstractAgent, Nothing}`: Currently active agent
- `context::Dict{Symbol, Any}`: Context variables
- `artifacts::Vector{Any}`: Tool outputs
- `io::Union{Nothing,IO}`: Output stream
- `rules::Vector{AbstractFlowRules}`: Session rules
- `agent_map::Dict{Symbol, <:AbstractAgent}`: Agent reference map
"""
Base.@kwdef mutable struct Session
    messages::Vector = PT.AbstractMessage[]
    agent::Union{AbstractAgent, Nothing} = nothing
    context::Dict{Symbol, Any} = Dict{Symbol, Any}()
    artifacts::Vector{Any} = Any[]
    io::Union{Nothing,IO} = stdout
    rules::Vector{AbstractFlowRules} = AbstractFlowRules[]
    agent_map::Dict{Symbol, <:AbstractAgent} = Dict{Symbol, AbstractAgent}()
end

# Constructor for Session with agent
Session(agent::AbstractAgent; io::Union{Nothing,IO}=stdout, context::Dict{Symbol,Any}=Dict{Symbol,Any}()) =
    Session(PT.AbstractMessage[], agent, context, Any[], io, AbstractFlowRules[], Dict{Symbol,AbstractAgent}())

# Show methods
function Base.show(io::IO, t::AbstractAgent)
    print(io, t.name, " (Tools: ", length(t.tool_map), ")")
end

function Base.show(io::IO, t::Session)
    agent_str = isnothing(t.agent) ? "None" : t.agent.name
    print(io, "Session (Messages: ", length(t.messages), ", Agent: ", agent_str, ")")
end

# Type checking utilities
"""
    isabstractagent(x)

Check if x is an AbstractAgent.
"""
isabstractagent(x::AbstractAgent) = true
isabstractagent(::Any) = false

"""
    isabstractagentref(x)

Check if x is an AbstractAgentRef.
"""
isabstractagentref(x::AbstractAgent) = x isa AbstractAgentRef
isabstractagentref(::Any) = false

"""
    isabstractagentactor(x)

Check if x is an AbstractAgentActor.
"""
isabstractagentactor(x::AbstractAgent) = x isa AbstractAgentActor
isabstractagentactor(::Any) = false

# Agent management functions
function find_agent(agent_map::Dict{Symbol, <:AbstractAgent}, agent_ref)
    if isabstractagentactor(agent_ref)
        return agent_ref
    end

    if agent_ref isa String
        agent_ref = Symbol(agent_ref)
    end

    if agent_ref isa AbstractAgentRef
        agent_ref = Symbol(agent_ref.name)
    end

    if !(agent_ref isa Symbol)
        throw(ArgumentError("Invalid agent reference type: $(typeof(agent_ref))"))
    end

    visited = Set{Symbol}()

    current_ref = agent_ref
    while true
        if current_ref in visited
            throw(ArgumentError("Circular reference detected in agent map"))
        end
        push!(visited, current_ref)

        if !haskey(agent_map, current_ref)
            throw(ArgumentError("Agent reference not found: $current_ref"))
        end

        agent = agent_map[current_ref]

        if isabstractagentactor(agent)
            return agent
        end

        if isabstractagentref(agent)
            current_ref = Symbol(agent.name)
            continue
        end

        throw(ArgumentError("Invalid agent type in map: $(typeof(agent))"))
    end
end

function add_agent!(session::Session, agent::AbstractAgent)
    agent_sym = Symbol(agent.name)
    if haskey(session.agent_map, agent_sym)
        @warn "Overwriting existing agent '$(agent.name)' in agent map"
        delete!(session.agent_map, agent_sym)
    end
    session.agent_map[agent_sym] = agent
    return nothing
end
