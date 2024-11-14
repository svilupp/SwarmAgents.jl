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

# Specific conversions to AbstractMessage
convert_message(::Type{AbstractMessage}, msg::SystemMessage) = msg
convert_message(::Type{AbstractMessage}, msg::UserMessage) = msg
convert_message(::Type{AbstractMessage}, msg::AIToolRequest) = msg
convert_message(::Type{AbstractMessage}, msg::ToolMessage) = msg

# Specific conversions between types
function convert_message(::Type{SystemMessage}, msg::AbstractMessage)
    SystemMessage(msg.content)
end

function convert_message(::Type{UserMessage}, msg::AbstractMessage)
    UserMessage(msg.content)
end

function convert_message(::Type{AIToolRequest}, msg::AbstractMessage)
    if msg isa ToolMessage
        AIToolRequest(msg.name, msg.args, msg.content, msg.tool_call_id)
    else
        AIToolRequest(msg.content)
    end
end

function convert_message(::Type{ToolMessage}, msg::AbstractMessage)
    if msg isa AIToolRequest
        ToolMessage(msg.name, msg.args, msg.content, msg.tool_call_id)
    else
        ToolMessage(msg.content)
    end
end

export convert_message
