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

# Specific conversions between message types
function convert_message(T::Type{<:SystemMessage}, msg::AbstractMessage)
    T(msg.content)
end

function convert_message(T::Type{<:UserMessage}, msg::AbstractMessage)
    T(msg.content)
end

function convert_message(T::Type{<:AIToolRequest}, msg::AbstractMessage)
    if msg isa ToolMessage
        T(msg.name, msg.args, msg.content, msg.tool_call_id)
    else
        T(msg.content)
    end
end

function convert_message(T::Type{<:ToolMessage}, msg::AbstractMessage)
    if msg isa AIToolRequest
        T(msg.name, msg.args, msg.content, msg.tool_call_id)
    else
        T("", nothing, msg.content, nothing, Dict(), :default)
    end
end

export convert_message
