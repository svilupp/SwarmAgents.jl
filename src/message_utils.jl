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

# Helper to extract content type
content_type(::Type{<:AbstractMessage{T}}) where T = T
content_type(::Type{<:AbstractMessage}) = String

# Specific conversions between message types with type parameter preservation
function convert_message(T::Type{<:SystemMessage}, msg::AbstractMessage)
    CT = content_type(T)
    SystemMessage{CT}(convert(CT, msg.content))
end

function convert_message(T::Type{<:UserMessage}, msg::AbstractMessage)
    CT = content_type(T)
    UserMessage{CT}(convert(CT, msg.content))
end

function convert_message(T::Type{<:AIToolRequest}, msg::AbstractMessage)
    CT = content_type(T)
    if msg isa ToolMessage
        AIToolRequest{CT}(msg.name, msg.args, convert(CT, msg.content), msg.tool_call_id)
    else
        AIToolRequest{CT}(convert(CT, msg.content))
    end
end

function convert_message(T::Type{<:ToolMessage}, msg::AbstractMessage)
    CT = content_type(T)
    if msg isa AIToolRequest
        ToolMessage{CT}(msg.name, msg.args, convert(CT, msg.content), msg.tool_call_id)
    else
        ToolMessage{CT}("", nothing, convert(CT, msg.content), nothing, Dict(), :default)
    end
end

export convert_message
