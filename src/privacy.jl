using PromptingTools
const PT = PromptingTools

"""
    PrivateMessage <: PT.AbstractMessage

A wrapper message type that defines message visibility for agents.

# Fields
- `object::PT.AbstractMessage`: The underlying message being wrapped
- `visible::Vector{String}`: List of agent names that can see this message
"""
struct PrivateMessage <: PT.AbstractMessage
    object::PT.AbstractMessage
    visible::Vector{String}
end

# Forward all AbstractMessage interface methods to the underlying object
PT.content(msg::PrivateMessage) = PT.content(msg.object)
PT.role(msg::PrivateMessage) = PT.role(msg.object)
PT.name(msg::PrivateMessage) = PT.name(msg.object)
PT.tool_calls(msg::PrivateMessage) = PT.tool_calls(msg.object)
PT.last_message(msgs::AbstractVector{<:PT.AbstractMessage}) = last(msgs)
PT.last_output(msgs::AbstractVector{<:PT.AbstractMessage}) = PT.last_output(last(msgs))

"""
    is_visible(message::PT.AbstractMessage, agent::Agent)::Bool

Determine if a message is visible to a specific agent.
Returns true for non-private messages, and checks visibility list for private messages.
"""
function is_visible(message::PT.AbstractMessage, agent::Agent)::Bool
    return true  # Non-private messages are visible to all
end

function is_visible(message::PrivateMessage, agent::Agent)::Bool
    return agent.name in message.visible
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

function maybe_private_message(message::PT.AbstractMessage, agent::Agent)
    return agent.private ? PrivateMessage(message, [agent.name]) : message
end

# Pretty printing
function Base.show(io::IO, msg::PrivateMessage)
    print(io, "PrivateMessage(visible=[", join(msg.visible, ", "), "])")
    print(io, "\n  └─ ", typeof(msg.object), ": ", PT.content(msg.object))
end

function PT.pprint(io::IO, msg::PrivateMessage; kwargs...)
    printstyled(io, "🔒 Private Message (visible to: ", join(msg.visible, ", "), ")\n", color=:light_black)
    PT.pprint(io, msg.object; kwargs...)
end

# Export the new functions
export PrivateMessage, is_visible, filter_history, maybe_private_message
