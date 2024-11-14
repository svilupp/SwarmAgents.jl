"""
    find_agent(agent_map::Dict{Symbol, AbstractAgent}, agent_ref::AbstractAgent)

Follow references through the agent map until finding a real agent that is not a reference.
If a real agent (not AbstractAgentRef) is provided, it's returned as is.
If an AgentRef is provided, follows references until finding a real agent or errors.

# Arguments
- `agent_map::Dict{Symbol, AbstractAgent}`: Map of agent references to actual agents
- `agent_ref::AbstractAgent`: Agent or agent reference to resolve

# Returns
- `AbstractAgentActor`: The resolved actual agent

# Throws
- `ArgumentError`: If agent reference cannot be resolved to a real agent
"""
function find_agent(agent_map::Dict{Symbol, AbstractAgent}, agent_ref::AbstractAgent)
    if isabstractagentactor(agent_ref)
        return agent_ref
    end

    # Convert agent name to symbol for lookup
    ref_name = Symbol(agent_ref.name)

    # Check if reference exists in map
    if !haskey(agent_map, ref_name)
        throw(ArgumentError("Agent reference '$(agent_ref.name)' not found in agent map"))
    end

    # Get the referenced agent
    referenced_agent = agent_map[ref_name]

    # If it's another reference, recurse
    if isabstractagentref(referenced_agent)
        return find_agent(agent_map, referenced_agent)
    end

    # If it's a real agent, return it
    if isabstractagentactor(referenced_agent)
        return referenced_agent
    end

    throw(ArgumentError("Invalid agent type found in agent map for '$(agent_ref.name)'"))
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
"""
function add_agent!(session::Session, agent::AbstractAgent)
    agent_name = Symbol(agent.name)
    if haskey(session.agent_map, agent_name)
        @warn "Overwriting existing agent '$(agent.name)' in agent map"
    end
    session.agent_map[agent_name] = agent
    return session
end

export find_agent, add_agent!
