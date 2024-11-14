"""
    get_used_tools(history::AbstractVector{<:PT.AbstractMessage}, agent::Union{Agent,Nothing}=nothing)

Get a list of all tools used in the message history, regardless of message privacy settings.
Privacy settings do not affect tool usage tracking as this is essential for flow control
and authentication state management.

# Arguments
- `history::AbstractVector{<:PT.AbstractMessage}`: The message history to analyze
- `agent::Union{Agent,Nothing}=nothing`: Optional agent (kept for API compatibility)

# Returns
- `Vector{Symbol}`: List of all tool names used in the message history
"""
function get_used_tools(history::AbstractVector{<:PT.AbstractMessage}, agent::Union{Agent,Nothing}=nothing)
    tools = Symbol[]
    for msg in history
        if PT.istoolmessage(msg)
            push!(tools, Symbol(msg.name))
        end
    end
    unique!(tools)
    return tools
end

export get_used_tools
