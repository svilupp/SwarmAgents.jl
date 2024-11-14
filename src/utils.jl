"""
    print_progress(io::Union{IO, Nothing}, agent::Union{AbstractAgent, Nothing}, msg::AbstractMessage)

Print progress messages for agent actions.
"""
function print_progress(io::Union{IO, Nothing}, agent::Union{AbstractAgent, Nothing}, msg)
    isnothing(io) && return nothing
    agent_name = isnothing(agent) ? "System" : agent.name
    printstyled(io, ">> $agent_name: ", color=:light_blue)
    if PT.isaitoolrequest(msg)
        tool_calls = msg.tool_calls
        if length(tool_calls) > 0
            printstyled(io, "Tool Request: Using tool: $(tool_calls[1].name)\n", color=:light_yellow)
            # Print tool arguments if present in the first tool call
            if hasfield(typeof(tool_calls[1]), :arguments)
                args = tool_calls[1].arguments
                if args isa AbstractDict
                    for (key, value) in args
                        printstyled(io, "$key: $value\n", color=:light_yellow)
                    end
                else
                    printstyled(io, "Arguments: $args\n", color=:light_yellow)
                end
            end
        else
            printstyled(io, "Tool Request: Using tool: unknown\n", color=:light_yellow)
        end
    elseif PT.istoolmessage(msg)
        printstyled(io, "Tool Output: Using tool: $(msg.name)\n", color=:light_yellow)
        if hasfield(typeof(msg), :args) && !isnothing(msg.args)
            args = msg.args
            if args isa AbstractDict
                for (key, value) in args
                    printstyled(io, "$key: $value\n", color=:light_yellow)
                end
            end
        end
        if !isnothing(msg.content)
            printstyled(io, "Tool response: $(msg.content)\n", color=:light_green)
        end
    else
        content = PT.last_output(msg)
        isnothing(content) && return nothing
        printstyled(io, content, "\n", color=:light_blue)
    end
    return nothing
end

"""
    scrub_agent_name(agent::AbstractAgent)

Clean up agent name for display.
"""
function scrub_agent_name(agent::AbstractAgent)
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
    elseif PT.isaimessage(msg)
        return T(msg.content, msg.name, msg.role, Dict{Symbol,Any}(), :assistant)
    elseif PT.istoolmessage(msg)
        return T(msg.content, msg.name, msg.tool_call_id, msg.conversation_id, Dict{Symbol,Any}(), msg.name, :default)
    elseif PT.isaitoolrequest(msg)
        return T(msg.content, msg.name, msg.role, Dict{Symbol,Any}(), :assistant, msg.tool_calls)
    else
        error("Unknown message type: $(typeof(msg))")
    end
end
