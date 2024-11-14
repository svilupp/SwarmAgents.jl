using PromptingTools
using PromptingTools: AbstractMessage, SystemMessage, UserMessage, AIToolRequest, ToolMessage

"""
    convert_message(T::Type{<:AbstractMessage}, msg::AbstractMessage)

Convert a message from one type to another within the PromptingTools ecosystem.
This is an internal utility function to handle message type conversions without type piracy.

# Notes
- Preserves tool-specific fields when converting between tool message types
- Handles conversion between UserMessage, SystemMessage, AIToolRequest, and ToolMessage
"""
# Base case: converting to same type is a no-op
convert_message(::Type{T}, msg::T) where T <: AbstractMessage = msg

# Converting to AbstractMessage returns the original message
convert_message(::Type{AbstractMessage}, msg::AbstractMessage) = msg

# Specific conversions
function convert_message(::Type{T}, msg::SystemMessage) where T <: AbstractMessage
    T(msg.content)
end

function convert_message(::Type{T}, msg::UserMessage) where T <: AbstractMessage
    T(msg.content)
end

function convert_message(::Type{T}, msg::AIToolRequest) where T <: AbstractMessage
    if T <: ToolMessage
        ToolMessage(msg.name, msg.args, msg.content, msg.tool_call_id)
    else
        T(msg.content)
    end
end

function convert_message(::Type{T}, msg::ToolMessage) where T <: AbstractMessage
    if T <: AIToolRequest
        AIToolRequest(msg.name, msg.args, msg.content, msg.tool_call_id)
    else
        T(msg.content)
    end
end

export convert_message
