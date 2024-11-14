"""
    print_progress(io::IO, agent::Union{Agent, Nothing}, msg::AbstractMessage)

Print progress messages for agent actions.
"""
function print_progress(io::IO, agent::Union{Agent, Nothing}, msg)
    agent_name = isnothing(agent) ? "System" : agent.name
    printstyled(io, ">> $agent_name: ", color=:light_blue)
    if PT.isaitoolrequest(msg)
        tool_calls = msg.tool_calls
        printstyled(io, "Using tool: $(length(tool_calls) > 0 ? tool_calls[1].name : "unknown")\n", color=:light_yellow)
    elseif PT.istoolmessage(msg)
        printstyled(io, "Tool response: $(msg.name)\n", color=:light_green)
        printstyled(io, msg.content, "\n", color=:light_green)
    else
        content = PT.last_output(msg)
        isnothing(content) && return
        printstyled(io, content, "\n", color=:light_blue)
    end
end

"""
    scrub_agent_name(agent::Agent)

Clean up agent name for display.
"""
function scrub_agent_name(agent::Agent)
    return replace(agent.name, r"[^a-zA-Z0-9]" => "_")
end

"""
    convert_message(T::Type{<:PT.AbstractMessage}, msg::PT.AbstractMessage)

Convert a message to the specified message type.
"""
function convert_message(T::Type{<:PT.AbstractMessage}, msg::PT.AbstractMessage)
    msg isa T && return msg
    if PT.issystemmessage(msg)
        return T(msg.content, msg.name, msg.role, Dict{Symbol,Any}(), :system)
    elseif PT.isusermessage(msg)
        return T(msg.content, msg.name, msg.role, Dict{Symbol,Any}(), :user)
    elseif PT.isassistantmessage(msg)
        return T(msg.content, msg.name, msg.role, Dict{Symbol,Any}(), :assistant)
    elseif PT.istoolmessage(msg)
        return T(msg.content, msg.name, msg.tool_call_id, msg.conversation_id, Dict{Symbol,Any}(), msg.name, :default)
    elseif PT.isaitoolrequest(msg)
        return T(msg.content, msg.name, msg.role, Dict{Symbol,Any}(), :assistant, msg.tool_calls)
    else
        error("Unknown message type: $(typeof(msg))")
    end
end
