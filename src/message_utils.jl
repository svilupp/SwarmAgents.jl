using PromptingTools
using PromptingTools: AbstractMessage, SystemMessage, UserMessage, AssistantMessage, AIMessage

# Convert methods for message types
function Base.convert(::Type{T}, msg::SystemMessage) where T <: AbstractMessage
    T(msg.content)
end

function Base.convert(::Type{T}, msg::UserMessage) where T <: AbstractMessage
    T(msg.content)
end

function Base.convert(::Type{T}, msg::AssistantMessage) where T <: AbstractMessage
    T(msg.content)
end

function Base.convert(::Type{T}, msg::AIMessage) where T <: AbstractMessage
    T(msg.content)
end

export convert
