using PromptingTools
using PromptingTools: AbstractMessage, SystemMessage, UserMessage, AIToolRequest, ToolMessage

"""
    convert_message(T::Type{<:AbstractMessage}, msg::AbstractMessage)

Convert a message from one type to another within the PromptingTools ecosystem.
This is an internal utility function to handle message type conversions without type piracy.

# Notes
- Preserves tool-specific fields when converting between tool message types
- Handles conversion between UserMessage, SystemMessage, AIToolRequest, and ToolMessage
- Preserves type parameters when converting between message types
"""
# Base case: converting to same type is a no-op
convert_message(::Type{T}, msg::T) where T <: AbstractMessage = msg

# Specific conversions to AbstractMessage
convert_message(::Type{AbstractMessage}, msg::AbstractMessage) = msg

# Specific conversions between types with type parameters
function convert_message(::Type{SystemMessage{T}}, msg::AbstractMessage) where T
    SystemMessage{T}(convert(T, msg.content))
end

function convert_message(::Type{UserMessage{T}}, msg::AbstractMessage) where T
    UserMessage{T}(convert(T, msg.content))
end

function convert_message(::Type{AIToolRequest{T}}, msg::AbstractMessage) where T
    if msg isa ToolMessage
        AIToolRequest{T}(msg.name, msg.args, convert(T, msg.content), msg.tool_call_id)
    else
        AIToolRequest{T}(convert(T, msg.content))
    end
end

function convert_message(::Type{ToolMessage{T}}, msg::AbstractMessage) where T
    if msg isa AIToolRequest
        ToolMessage{T}(msg.name, msg.args, convert(T, msg.content), msg.tool_call_id)
    else
        ToolMessage{T}(convert(T, msg.content))
    end
end

# Convenience methods for non-parameterized types
function convert_message(::Type{M}, msg::AbstractMessage) where M <: AbstractMessage
    T = eltype(M)
    convert_message(M{T}, msg)
end

export convert_message
