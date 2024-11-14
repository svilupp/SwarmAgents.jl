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
    # Track visited references to detect cycles
    visited = Set{Symbol}()

    function resolve_ref(current_ref)
        if current_ref isa String
            current_ref = Symbol(current_ref)
        end

        if current_ref isa Symbol
            if current_ref in visited
                throw(ArgumentError("Circular reference detected in agent map"))
            end
            push!(visited, current_ref)

            !haskey(agent_map, current_ref) &&
                throw(ArgumentError("Agent reference not found: $current_ref"))
            return resolve_ref(agent_map[current_ref])
        end

        if current_ref isa AbstractAgent
            if isabstractagentactor(current_ref)
                return current_ref
            elseif isabstractagentref(current_ref)
                return resolve_ref(Symbol(current_ref.name))
            end
        end

        throw(ArgumentError("Invalid agent reference type: $(typeof(current_ref))"))
    end

    resolve_ref(agent_ref)
end

export AbstractAgent, AbstractAgentActor, AbstractAgentRef, AgentRef,
    isabstractagent, isabstractagentref, isabstractagentactor,
    find_agent
