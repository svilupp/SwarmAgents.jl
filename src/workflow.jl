"""
    handle_tool_calls!(active_agent::Union{Agent, Nothing}, history::AbstractVector{<:PT.AbstractMessage}, session::Session)

Handle tool calls for an agent. Tools are executed directly using the agent's tool_map.
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

        # Execute tool directly using agent's tool_map
        output = PT.execute_tool(active_agent.tool_map, tool, session.context)
        push!(session.artifacts, output)

        ## Changing the agent
        if isabstractagent(output)
            next_agent = output
            payload = Dict(:assistant => next_agent.name)
            !isempty(args) && merge!(payload, args)
            output = JSON3.write(payload)
            # Mark previous messages in this turn as last_turn since we're changing agents
            for i in (length(history)-length(tool_calls(history[end]))):length(history)
                if i > 0 && history[i] isa PrivateMessage
                    history[i] = PrivateMessage(history[i].object, history[i].visible, true)
                end
            end
        end
        # Update the tool's content using our custom tool_output for proper string conversion of various output types
        tool.content = tool_output(output)
        # Tool messages are private unless they're the last in a sequence (when next_agent changes)
        output_msg = maybe_private_message(tool, active_agent; last_turn=(next_agent !== active_agent))
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
    run_full_turn(agent::AbstractAgent, messages::AbstractVector{<:PT.AbstractMessage}, session::Session; max_turns::Int = 5, combine::Function = vcat)

Run a full turn of an agent, executing all tool calls with proper tool filtering and termination checks.

# Arguments
- `agent::AbstractAgent`: The agent to run the turn for
- `messages::AbstractVector{<:PT.AbstractMessage}`: Initial message history
- `session::Session`: Session containing rules and context
- `max_turns::Int = 5`: Maximum number of turns to execute
- `combine::Function = vcat`: Function to combine results from multiple tool rules (must use vcat for multiple tools)

# Notes
- Tools are filtered using get_allowed_tools based on session rules
- Available tools come from agent's tool_map
- If no tool rules exist, all agent tools are available
- Tool selection respects AbstractToolFlowRules filtering
- For single tool usage, wrap tool in FixedOrder: FixedOrder(tool)
- For multiple tools, use vcat as combine function to merge tool lists
- Termination checks are run after each tool execution
"""
function run_full_turn(agent::AbstractAgent, messages::AbstractVector{<:PT.AbstractMessage}, session::Session; max_turns::Int = 5, combine::Function = vcat, kwargs...)
    active_agent = isabstractagentref(agent) ? find_agent(session.agent_map, agent) : agent
    history = deepcopy(messages)
    init_len = length(messages)
    used_tools = String[]

    while (length(history) - init_len) < max_turns && !isnothing(active_agent)
        # Get all available tools from the agent's tool_map
        all_tools = String[string(name) for name in keys(active_agent.tool_map)]

        # Get allowed tools based on rules and used tools
        allowed_names = get_allowed_tools(session.rules, used_tools, all_tools; combine=combine)

        # Convert allowed tools to a vector for aitools
        tools = [active_agent.tool_map[name] for name in allowed_names]

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
            # Make the message public if it's an assistant message with no tool calls
            is_last = PT.isaimessage(msg) && isempty(tool_calls(msg))
            private_msg = maybe_private_message(converted_msg, active_agent; last_turn=is_last)
            push!(history, private_msg)
        end

        # Print assistant response
        if !isnothing(PT.last_output(response))
            print_progress(session.io, active_agent, response[end])
        end
        isempty(tool_calls(response[end])) && break

        # Run tool calls and update used tools
        (; active_agent, history) = handle_tool_calls!(active_agent, history, session)
        new_tools = get_used_tools(history)
        append!(used_tools, String[string(t) for t in new_tools])
        # Don't use unique! here to preserve duplicates for vcat
        if combine !== vcat
            unique!(used_tools)
        end

        # Run termination checks
        termination_rules = filter(r -> r isa AbstractTerminationFlowRules, session.rules)
        active_agent = run_termination_checks(history, active_agent, session.io, termination_rules)
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
end  # End of add_tools!

"""
    transfer_agent(target_agent_name::String, handover_message::String) -> AgentRef

Generic transfer function that creates an AgentRef for the specified target agent.
This function supports introspection via PT.get_arg_names and PT.get_arg_types.

# Arguments
- `target_agent_name::String`: Name of the target agent to transfer to
- `handover_message::String`: Explanation for why the transfer is needed

# Returns
- `AgentRef`: Reference to the target agent

# Example
```julia
# Transfer to "Support Agent" with explanation
new_agent = transfer_agent("Support Agent", "Customer needs technical assistance")
```
"""
function transfer_agent(target_agent_name::String, handover_message::String)::AgentRef
    return AgentRef(target_agent_name)
end

"""
    add_transfers!(session::Session)

Add transfer tools to each agent in the session's agent_map to enable transfers between agents.
For each agent, creates transfer functions to all other agents (except itself) and adds them as tools.

Each transfer tool includes a handover_message parameter to explain the reason for transfer.

Example:
```julia
# If agent_map contains "Booking Agent" and "Support Agent"
# Creates tools:
# - transfer_to_booking_agent(handover_message::String) for Support Agent
# - transfer_to_support_agent(handover_message::String) for Booking Agent
```
"""
function add_transfers!(session::Session)
    # Get all agents from the map
    agents = collect(values(session.agent_map))
    agent_names = [agent.name for agent in agents]

    # For each agent, create transfer tools to all other agents
    for source_agent in agents
        source_name = source_agent.name

        # Get available target agents (excluding self)
        available_targets = filter(name -> name != source_name, agent_names)
        available_targets_str = join(available_targets, ", ")

        # Create transfer tools for all other agents
        for target_agent in agents
            target_name = target_agent.name

            # Skip creating transfer to self
            if source_name == target_name
                @debug "Skipping self-transfer" source_name target_name
                continue
            end

            # Create snake_case function name (e.g., "Booking Agent" -> "transfer_to_booking_agent")
            target_snake = lowercase(replace(target_name, r"[^a-zA-Z0-9]+" => "_"))
            function_name = "transfer_to_$target_snake"

            try
                # Create parameters dictionary
                parameters = Dict(
                    "handover_message" => Dict(
                        "type" => "string",
                        "description" => "Explanation for why the transfer is needed",
                        "required" => true
                    )
                )

                # Use generic transfer_agent function with target_name binding
                transfer_fn = (args...; kwargs...) -> transfer_agent(target_name, kwargs[:handover_message])

                # Create docstring
                docs = """
                    Transfer conversation to $target_name.

                    Available agents for transfer from $source_name: $available_targets_str

                    Parameters:
                    - handover_message::String: Required explanation for the transfer

                    Returns:
                    - AgentRef: Reference to $target_name agent
                """

                # Create tool with explicit kwargs
                tool = Tool(;
                    name=function_name,
                    parameters=parameters,
                    description=docs,
                    callable=transfer_fn
                )

                add_tools!(source_agent, tool)
            catch e
                @error "Failed to create or add tool" exception=(e, catch_backtrace()) function_name target_name
                @error "Tool creation details" step="last_known" parameters=get(Base.current_exceptions(), :parameters, nothing)
                @error "Function details" fn_type=get(Base.current_exceptions(), :fn_type, nothing)
                rethrow(e)
            end
        end
    end
    return nothing
end
