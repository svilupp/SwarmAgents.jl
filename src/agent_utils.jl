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
    find_agent(agent_map::Dict{Symbol, AbstractAgent}, agent_ref)

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
function find_agent(agent_map::Dict{Symbol, AbstractAgent}, agent_ref)
    # Handle string input
    if agent_ref isa String
        agent_ref = Symbol(agent_ref)
    end

    # Handle symbol input
    if agent_ref isa Symbol
        !haskey(agent_map, agent_ref) &&
            throw(ArgumentError("Agent reference not found: $agent_ref"))
        return find_agent(agent_map, agent_map[agent_ref])
    end

    # Handle agent input
    if agent_ref isa AbstractAgent
        if isabstractagentactor(agent_ref)
            return agent_ref
        elseif isabstractagentref(agent_ref)
            return find_agent(agent_map, Symbol(agent_ref.name))
        end
    end

    throw(ArgumentError("Invalid agent reference type: $(typeof(agent_ref))"))
end

"""
    add_agent!(session::Session, agent::AbstractAgent)

Add an agent to the session's agent map. If an agent with the same name already exists,
a warning is issued before overwriting.

# Arguments
- `session::Session`: The session to add the agent to
- `agent::AbstractAgent`: The agent to add

# Returns
- `Session`: The modified session

# Notes
- Issues a warning if overwriting an existing agent
- Only adds the agent if it's an AbstractAgentRef
"""
function add_agent!(session::Session, agent::AbstractAgent)
    if isabstractagentref(agent)
        agent_name = Symbol(agent.name)
        if haskey(session.agent_map, agent_name)
            @warn "Overwriting existing agent '$(agent.name)' in agent map"
        end
        session.agent_map[agent_name] = agent
    end
    return session
end

export AbstractAgent, AbstractAgentActor, AbstractAgentRef,
    isabstractagentref, isabstractagentactor,
    find_agent, add_agent!
