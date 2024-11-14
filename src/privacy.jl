"""
    PrivateMessage <: PT.AbstractMessage

A wrapper message type that defines message visibility for agents.

Message Visibility Rules:
- Messages from private agents are wrapped in PrivateMessage
- Messages are made public (visible to all agents) in the following cases:
  1. Last turn of an agent's sequence (marked with last_turn=true)
  2. Assistant messages with no tool calls (to explain why tool calls stopped)
  3. Messages from agent handoff (when a new agent is selected)
- Only intermediate tool calls remain private
This ensures that following agents understand why they were called while
maintaining privacy of intermediate processing steps.

# Fields
- `object::PT.AbstractMessage`: The underlying message being wrapped
- `visible::Vector{String}`: List of agent names that can see this message
- `last_turn::Bool`: Indicates if this message is from the last turn of an agent
"""
struct PrivateMessage <: PT.AbstractMessage
    object::PT.AbstractMessage
    visible::Vector{String}
    last_turn::Bool  # Indicates if this message is from the last turn of an agent
end

# Constructor with default last_turn=false for backward compatibility
PrivateMessage(object::PT.AbstractMessage, visible::Vector{String}) = PrivateMessage(object, visible, false)

# Forward essential methods to the underlying object
PT.tool_calls(msg::PrivateMessage) = PT.tool_calls(msg.object)
PT.last_output(msg::PrivateMessage) = PT.last_output(msg.object)

"""
    is_visible(message::PT.AbstractMessage, agent::Agent)::Bool

Determine if a message is visible to a specific agent.
Returns true for non-private messages, and checks visibility list for private messages.
"""
function is_visible(message::PT.AbstractMessage, agent::Agent)::Bool
    return true  # Non-private messages are visible to all
end

function is_visible(message::PrivateMessage, agent::Agent)::Bool
    return agent.name in message.visible || message.last_turn
end

"""
    filter_history(history::AbstractVector{<:PT.AbstractMessage}, agent::Agent)

Filter message history to only include messages visible to the specified agent.
"""
function filter_history(history::AbstractVector{<:PT.AbstractMessage}, agent::Agent)
    return filter(msg -> is_visible(msg, agent), history)
end

"""
    maybe_private_message(message::PT.AbstractMessage, agent::Agent)

Wrap a message in a PrivateMessage if the agent is private.
"""
# Add method for nothing case
function maybe_private_message(message::PT.AbstractMessage, agent::Nothing)
    return message  # When no agent, return message as-is
end

function maybe_private_message(message::PT.AbstractMessage, agent::Agent; last_turn::Bool=false)
    return agent.private ? PrivateMessage(message, [agent.name], last_turn) : message
end

# Pretty printing
function Base.show(io::IO, msg::PrivateMessage)
    print(io, "PrivateMessage(visible=[", join(msg.visible, ", "), "], last_turn=", msg.last_turn, ")")
    print(io, "\n  └─ ", typeof(msg.object))
end

function PT.pprint(io::IO, msg::PrivateMessage; kwargs...)
    printstyled(io, "🔒 Private Message (visible to: ", join(msg.visible, ", "), ", last_turn=", msg.last_turn, ")\n", color=:light_black)
    PT.pprint(io, msg.object; kwargs...)
end
