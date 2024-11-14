using PromptingTools
using PromptingTools: AbstractMessage, SystemMessage, UserMessage

# Convert methods for message types
function Base.convert(::Type{T}, msg::SystemMessage) where T <: AbstractMessage
    T(msg.content)
end

function Base.convert(::Type{T}, msg::UserMessage) where T <: AbstractMessage
    T(msg.content)
end

export convert
