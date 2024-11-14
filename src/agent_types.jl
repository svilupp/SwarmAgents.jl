using PromptingTools: AbstractMessage

"""
    AbstractAgent

Abstract type for all agent types in SwarmAgents.
"""
abstract type AbstractAgent end

"""
    AgentRef(name::String)

Reference to an agent in the agent map.

# Fields
- `name::String`: Name of the referenced agent

# Notes
- Used to reference agents stored in Session.agent_map
- Names are converted to symbols for lookup
"""
struct AgentRef <: AbstractAgent
    name::String
end

"""
    isabstractagentref(x)

Check if x is an AgentRef.

# Arguments
- `x`: Object to check

# Returns
- `Bool`: true if x is an AgentRef
"""
isabstractagentref(x) = x isa AgentRef

"""
    isabstractagentactor(x)

Check if x is a concrete agent (not a reference).

# Arguments
- `x`: Object to check

# Returns
- `Bool`: true if x is a concrete agent
"""
isabstractagentactor(x) = x isa AbstractAgent && !isabstractagentref(x)

"""
    find_agent(agent_map::Dict{Symbol, <:AbstractAgent}, agent_ref::AgentRef)

Follow agent references through the agent map until finding a concrete agent.

# Arguments
- `agent_map`: Dictionary mapping agent names to agents
- `agent_ref`: Reference to resolve

# Returns
- `AbstractAgent`: The resolved concrete agent

# Throws
- `ArgumentError`: If agent reference cannot be resolved
"""
function find_agent(agent_map::Dict{Symbol, <:AbstractAgent}, agent_ref::AgentRef)
    current_ref = agent_ref
    visited = Set{Symbol}()
    while true
        ref_sym = Symbol(current_ref.name)
        ref_sym in visited && throw(ArgumentError("Circular reference detected for agent '$(current_ref.name)'"))
        push!(visited, ref_sym)

        agent = get(agent_map, ref_sym, nothing)
        isnothing(agent) && throw(ArgumentError("Agent '$(current_ref.name)' not found in agent map"))

        if isabstractagentactor(agent)
            return agent
        else
            current_ref = agent
        end
    end
end

# Passthrough for concrete agents
find_agent(agent_map::Dict{Symbol, <:AbstractAgent}, agent::AbstractAgent) = agent

"""
    add_agent!(session::Session, agent::AbstractAgent)

Add an agent to the session's agent map.

# Arguments
- `session`: Session to add agent to
- `agent`: Agent to add

# Notes
- Warns if overwriting an existing agent
- Agent names are converted to symbols for storage
"""
function add_agent!(session::Session, agent::AbstractAgent)
    agent_name = Symbol(agent.name)
    if haskey(session.agent_map, agent_name)
        @warn "Overwriting existing agent '$(agent.name)' in agent map"
    end
    session.agent_map[agent_name] = agent
    return session
end

export AbstractAgent, AgentRef,
    isabstractagentref, isabstractagentactor,
    find_agent, add_agent!
