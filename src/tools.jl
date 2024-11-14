"""
    get_used_tools(history::AbstractVector{<:PT.AbstractMessage}, agent::Union{Agent,Nothing}=nothing)

Get a list of tools used in the message history. If an agent is provided, only returns tools from messages visible to that agent.

# Arguments
- `history::AbstractVector{<:PT.AbstractMessage}`: The message history to analyze
- `agent::Union{Agent,Nothing}=nothing`: Optional agent to filter messages by visibility

# Returns
- `Vector{Symbol}`: List of tool names used in the visible messages
"""
function get_used_tools(history::AbstractVector{<:PT.AbstractMessage}, agent::Union{Agent,Nothing}=nothing)
    # Filter history if agent is provided
    visible_history = isnothing(agent) ? history : filter_history(history, agent)

    tools = Symbol[]
    for msg in visible_history
        if PT.istoolmessage(msg)
            push!(tools, Symbol(msg.name))
        end
    end
    unique!(tools)
    return tools
end

export get_used_tools
