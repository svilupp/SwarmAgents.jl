"""
    handle_tool_calls!(
        active_agent::Union{Agent, Nothing}, history::AbstractVector{<:PT.AbstractMessage},
        context::Dict{Symbol, Any} = Dict{Symbol, Any}())

Handles tool calls for an agent.
"""
function handle_tool_calls!(
        active_agent::Union{Agent, Nothing}, history::AbstractVector{<:PT.AbstractMessage},
        context::Dict{Symbol, Any} = Dict{Symbol, Any}())
    last_msg = PT.last_message(history)
    @assert PT.isaitoolrequest(last_msg) "Last message must be an AIToolsRequest! Provided: $(last_msg|>typeof)"

    isempty(last_msg.tool_calls) && return (; active_agent, history, context)
    next_agent = active_agent
    for tool in tool_calls(history[end])
        if isnothing(active_agent)
            println("Early exit: no active agent!")
            continue
        end
        name, args = tool.name, tool.args
        printstyled(">> Tool Request: $name, args: $args\n", color = :light_blue)
        @assert name ∈ keys(active_agent.tool_map) "Tool $name not found in agent $(active_agent.name)'s tool map."
        ## TODO: add try-catch for function errors
        output = PT.execute_tool(active_agent.tool_map, tool, context)
        ## Changing the agent
        if isabstractagent(output)
            next_agent = output
            output = JSON3.write(Dict(:assistant => next_agent.name))
        end
        tool.content = output
        printstyled(">> Tool Output: $(tool.content)\n", color = :light_blue)
        push!(history, tool)
    end
    return (; active_agent = next_agent, history, context)
end

"""
    update_system_message!(history::AbstractVector{<:PT.AbstractMessage},
        active_agent::Union{Agent, Nothing})

Updates the system message in the history (1st message) with the `active agent`'s instructions.
"""
function update_system_message!(history::AbstractVector{<:PT.AbstractMessage},
        active_agent::Union{Agent, Nothing})
    isnothing(active_agent) && return history
    if length(history) > 1 && PT.issystemmessage(history[1]) &&
       !isempty(active_agent.instructions)
        ## Update the system message
        history[1] = PT.SystemMessage(active_agent.instructions)
    else
        ## Add the system message to the beginning of the history
        pushfirst!(history, PT.SystemMessage(active_agent.instructions))
    end
    return history
end

"""
    run_full_turn(agent::Agent, messages::AbstractVector{<:PT.AbstractMessage},
        context::Dict{Symbol, Any} = Dict{Symbol, Any}(); max_turns::Int = 5,
        kwargs...)

Runs a full turn of an agent (executes all tool calls).
"""
function run_full_turn(agent::Agent, messages::AbstractVector{<:PT.AbstractMessage},
        context::Dict{Symbol, Any} = Dict{Symbol, Any}(); max_turns::Int = 5,
        kwargs...)
    active_agent = agent
    context = deepcopy(context)
    history = deepcopy(messages)
    init_len = length(messages)

    while (length(history) - init_len) < max_turns && !isnothing(active_agent)
        tools = collect(values(active_agent.tool_map))
        update_system_message!(history, active_agent)
        history = PT.aitools(history; model = active_agent.model,
            tools, name_user = "User", name_assistant = scrub_agent_name(active_agent),
            return_all = true, verbose = false, kwargs...)
        # Print assistant response
        !isnothing(PT.last_output(history)) &&
            printstyled(">> Assistant: $(PT.last_output(history))\n", color = :magenta)
        isempty(tool_calls(history[end])) && break
        # Run tool calls
        (; active_agent, history, context) = handle_tool_calls!(
            active_agent, history, context)
    end
    return Response(;
        messages = history[min(init_len + 1, end):end],
        agent = active_agent,
        context = context
    )
end
function run_full_turn!(session::Session, user_prompt::AbstractString; kwargs...)
    @assert !isnothing(session.agent) "Session has no active agent!"
    @assert !isnothing(user_prompt) "User prompt cannot be nothing!"
    ## At the user prompt
    push!(session.messages, PT.UserMessage(user_prompt))
    printstyled(">> User: $user_prompt\n", color = :light_red)
    resp = run_full_turn(session.agent, session.messages, session.context; kwargs...)
    session.messages = vcat(session.messages, resp.messages)
    session.agent = resp.agent
    session.context = resp.context
    return session
end

"""
    Session(agent::Agent;
        context::Dict{Symbol, Any} = Dict{Symbol, Any}())

Initializes a `Session` with an `agent` and an optional `context`.

Run `run_full_turn!` with a `user_prompt` to continue the session.
"""
function Session(agent::Agent;
        context::Dict{Symbol, Any} = Dict{Symbol, Any}())
    return Session(; agent, context)
end