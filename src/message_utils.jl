using PromptingTools
using PromptingTools: AbstractMessage, SystemMessage, UserMessage, AIToolRequest

"""
    convert_message(T::Type{<:AbstractMessage}, msg::SystemMessage)
    convert_message(T::Type{<:AbstractMessage}, msg::UserMessage)
    convert_message(T::Type{<:AbstractMessage}, msg::AIToolRequest)

Convert a message from one type to another within the PromptingTools ecosystem.
This is an internal utility function to handle message type conversions without type piracy.
"""
function convert_message(::Type{T}, msg::SystemMessage) where T <: AbstractMessage
    T(msg.content)
end

function convert_message(::Type{T}, msg::UserMessage) where T <: AbstractMessage
    T(msg.content)
end

function convert_message(::Type{T}, msg::AIToolRequest) where T <: AbstractMessage
    T(msg.content)
end

export convert_message
