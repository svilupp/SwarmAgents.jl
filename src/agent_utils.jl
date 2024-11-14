"""
Abstract type hierarchy for agents in SwarmAgents.
"""
abstract type AbstractAgent end

"""
Abstract type for agent actors that can perform actions.
"""
abstract type AbstractAgentActor <: AbstractAgent end

"""
Abstract type for agent references that point to other agents.
"""
abstract type AbstractAgentRef <: AbstractAgent end

"""
    AgentRef <: AbstractAgentRef

A reference to another agent in the system.

# Fields
- `name::String`: The name of the referenced agent
"""
struct AgentRef <: AbstractAgentRef
    name::String
    AgentRef(name::String) = new(name)
    AgentRef(; name::String) = new(name)
end

"""
    isabstractagent(agent) -> Bool

Check if an object is an AbstractAgent.

# Arguments
- `agent`: Object to check

# Returns
- `Bool`: true if agent is an AbstractAgent, false otherwise
"""
isabstractagent(agent::AbstractAgent) = true
isabstractagent(::Any) = false

"""
    isabstractagentref(agent) -> Bool

Check if an agent is an AbstractAgentRef.

# Arguments
- `agent`: Agent to check

# Returns
- `Bool`: true if agent is an AbstractAgentRef, false otherwise
"""
isabstractagentref(agent::AbstractAgent) = agent isa AbstractAgentRef
isabstractagentref(::Any) = false

"""
    isabstractagentactor(agent) -> Bool

Check if an agent is an AbstractAgentActor.

# Arguments
- `agent`: Agent to check

# Returns
- `Bool`: true if agent is an AbstractAgentActor, false otherwise
"""
isabstractagentactor(agent::AbstractAgent) = agent isa AbstractAgentActor
isabstractagentactor(::Any) = false

"""
    find_agent(agent_map::Dict{Symbol, <:AbstractAgent}, agent_ref)

Follow references through the agent map until finding a real agent that is not a reference.
If a real agent (not AbstractAgentRef) is provided, it's returned as is.
If an AgentRef is provided, follows references until finding a real agent or errors.

# Arguments
- `agent_map::Dict{Symbol, AbstractAgent}`: Map of agent references to actual agents
- `agent_ref`: Agent, agent reference, or string name to resolve

# Returns
- `AbstractAgentActor`: The resolved actual agent

# Throws
- `ArgumentError`: If agent reference cannot be resolved to a real agent

# Notes
- Agent names are strings, refs are symbols
- If a real agent (not AbstractAgentRef) is provided, it's returned as-is
- Agent structs do not have to be in agent_map, only AgentRefs must be there
"""
function find_agent(agent_map::Dict{Symbol, <:AbstractAgent}, agent_ref)
    # If it's already an actor, return it immediately
    if isabstractagentactor(agent_ref)
        return agent_ref
    end

    # Convert string to symbol if needed
    if agent_ref isa String
        agent_ref = Symbol(agent_ref)
    end

    # If it's a reference, get its name as symbol
    if agent_ref isa AbstractAgentRef
        agent_ref = Symbol(agent_ref.name)
    end

    # At this point, agent_ref should be a Symbol
    if !(agent_ref isa Symbol)
        throw(ArgumentError("Invalid agent reference type: $(typeof(agent_ref))"))
    end

    # Track visited references to detect cycles
    visited = Set{Symbol}()

    # Follow the reference chain
    current_ref = agent_ref
    while true
        # Check for cycles
        if current_ref in visited
            throw(ArgumentError("Circular reference detected in agent map"))
        end
        push!(visited, current_ref)

        # Check if reference exists
        if !haskey(agent_map, current_ref)
            throw(ArgumentError("Agent reference not found: $current_ref"))
        end

        # Get the referenced agent
        agent = agent_map[current_ref]

        # If it's an actor, we're done
        if isabstractagentactor(agent)
            return agent
        end

        # If it's a reference, continue following the chain
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
        # Ensure the new agent completely replaces the old one
        delete!(session.agent_map, agent_sym)
    end
    session.agent_map[agent_sym] = agent
    return nothing
end

export AbstractAgent, AbstractAgentActor, AbstractAgentRef, AgentRef,
    isabstractagent, isabstractagentref, isabstractagentactor,
    find_agent, add_agent!
