using PromptingTools: AbstractMessage

"""
    AbstractAgent

Abstract type for all agent types in SwarmAgents.
"""
abstract type AbstractAgent end

"""
    AgentRef(name::String)
    AgentRef(; name::String)

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

# Add keyword constructor
AgentRef(; name::String) = AgentRef(name)

"""
    isabstractagent(x)

Check if x is an AbstractAgent.

# Arguments
- `x`: Object to check

# Returns
- `Bool`: true if x is an AbstractAgent
"""
isabstractagent(x) = x isa AbstractAgent

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

export AbstractAgent, AgentRef,
    isabstractagent, isabstractagentref, isabstractagentactor
