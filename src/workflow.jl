"""
    handle_tool_calls!(active_agent::Union{Agent, Nothing}, history::AbstractVector{<:PT.AbstractMessage}, session::Session)

Handle tool calls for an agent.
"""
function handle_tool_calls!(active_agent::Union{Agent, Nothing}, history::AbstractVector{<:PT.AbstractMessage}, session::Session)
    last_msg = PT.last_message(history)
    @assert PT.isaitoolrequest(last_msg) "Last message must be an AIToolsRequest! Provided: $(last_msg|>typeof)"

    isempty(last_msg.tool_calls) && return (; active_agent, history, context = session.context)
    next_agent = active_agent
    for tool in tool_calls(history[end])
        if isnothing(active_agent)
            print_progress(session.io, active_agent, ToolMessage("Early exit", nothing, "Early exit", "Early exit", Dict{Symbol,Any}(), "Early exit", :default))
            continue
        end
        name, args = tool.name, tool.args
        print_progress(session.io, active_agent, tool)
        @assert name ∈ keys(active_agent.tool_map) || name ∈ keys(session.rules) "Tool $name not found in agent $(active_agent.name)'s tool map or session rules."

        # Get tool from agent's tool_map or session rules
        tool_impl = get(active_agent.tool_map, name, nothing)
        if isnothing(tool_impl)
            tool_impl = session.rules[name]
        end

        ## Execute tool and store full output in artifacts
        # Extract the underlying tool if it's a ToolFlowRules
        tool_impl = tool_impl isa ToolFlowRules ? tool_impl.tool : tool_impl
        output = PT.execute_tool(Dict(name => tool_impl), tool, session.context)
        push!(session.artifacts, output)

        ## Changing the agent
        if isabstractagent(output)
            next_agent = output
            payload = Dict(:assistant => next_agent.name)
            !isempty(args) && merge!(payload, args)
            output = JSON3.write(payload)
        end
        # Create a new ToolMessage with the output content and wrap if agent is private
        output_msg = ToolMessage(string(output), nothing, tool.tool_call_id, tool.tool_call_id, Dict{Symbol,Any}(), tool.name, :default)
        output_msg = maybe_private_message(output_msg, active_agent)
        print_progress(session.io, active_agent, output_msg)
        push!(history, output_msg)
    end
    return (; active_agent = next_agent, history, context = session.context)
end

"""
    update_system_message!(history::AbstractVector{<:PT.AbstractMessage}, active_agent::Union{Agent, Nothing})

Update the system message in the history with the active agent's instructions.
"""
function update_system_message!(history::AbstractVector{T}, active_agent::Union{Agent, Nothing}) where T <: PT.AbstractMessage
    isnothing(active_agent) && return history
    if length(history) > 1 && PT.issystemmessage(history[1]) && !isempty(active_agent.instructions)
        history[1] = convert_message(T, PT.SystemMessage(active_agent.instructions))
    else
        pushfirst!(history, convert_message(T, PT.SystemMessage(active_agent.instructions)))
    end
    return history
end

"""
    run_full_turn(agent::AbstractAgent, messages::AbstractVector{<:PT.AbstractMessage}, session::Session; max_turns::Int = 5)

Run a full turn of an agent (executes all tool calls).
"""
function run_full_turn(agent::AbstractAgent, messages::AbstractVector{<:PT.AbstractMessage}, session::Session; max_turns::Int = 5, kwargs...)
    active_agent = isabstractagentref(agent) ? find_agent(session.agent_map, agent) : agent
    history = deepcopy(messages)
    init_len = length(messages)

    while (length(history) - init_len) < max_turns && !isnothing(active_agent)
        # Combine tools from agent and session
        tools = vcat(collect(values(active_agent.tool_map)), collect(values(session.rules)))

        # Create a filtered copy of history for AI processing
        filtered_history = filter_history(history, active_agent)
        update_system_message!(filtered_history, active_agent)

        # Get AI response using filtered history
        response = PT.aitools(filtered_history;
            model = active_agent.model,
            tools,
            name_user = "User",
            name_assistant = scrub_agent_name(active_agent),
            return_all = true,
            verbose = false,
            kwargs...)

        # Add only new messages to history with privacy handling
        filtered_len = length(filtered_history)
        for msg in response[filtered_len+1:end]
            converted_msg = convert_message(eltype(history), msg)
            private_msg = maybe_private_message(converted_msg, active_agent)
            push!(history, private_msg)
        end

        # Print assistant response
        if !isnothing(PT.last_output(response))
            print_progress(session.io, active_agent, response[end])
        end
        isempty(tool_calls(response[end])) && break

        # Run tool calls
        (; active_agent, history) = handle_tool_calls!(active_agent, history, session)
    end

    return Response(;
        messages = history[min(init_len + 2, end):end],
        agent = active_agent,
        context = session.context
    )
end

"""
    run_full_turn!(session::Session, user_prompt::AbstractString; kwargs...)

Run a full turn with a user prompt, updating the session state.
"""
function run_full_turn!(session::Session, user_prompt::AbstractString; kwargs...)
    @assert !isnothing(session.agent) "Session has no active agent!"
    @assert !isnothing(user_prompt) "User prompt cannot be nothing!"

    push!(session.messages, PT.UserMessage(user_prompt))
    printstyled(">> User: $user_prompt\n", color = :light_red)

    resp = run_full_turn(session.agent, session.messages, session; kwargs...)
    session.messages = vcat(session.messages, resp.messages)
    session.agent = resp.agent
    session.context = resp.context

    return session
end

### Tools Management
"""
    add_tools!(agent::Agent, tools::Vector)

Adds `tools` to an `agent`.
"""
function add_tools!(agent::Agent, tools::Vector; kwargs...)
    for tool in tools
        add_tools!(agent, tool; kwargs...)
    end
end

function add_tools!(agent::Agent, tool::AbstractTool; kwargs...)
    @assert tool.name∉keys(agent.tool_map) "Tool $(tool.name) already exists. Only unique tool names are allowed."
    agent.tool_map[tool.name] = tool
end

function add_tools!(agent::Agent, callable::Union{Function, Type, Method}; kwargs...)
    add_tools!(agent, Tool(callable; kwargs...))
end
