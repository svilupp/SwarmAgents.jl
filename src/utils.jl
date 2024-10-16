"""
    add_tools!(agent::Agent, tools::Vector)

Adds `tools` to an `agent`.
"""
function add_tools!(agent::Agent, tools::Vector)
    for tool in tools
        add_tools!(agent, tool)
    end
end
function add_tools!(agent::Agent, tool::AbstractTool)
    @assert tool.name∉keys(agent.tool_map) "Tool $(tool.name) already exists. Only unique tool names are allowed."
    agent.tool_map[tool.name] = tool
end
function add_tools!(agent::Agent, callable::Union{Function, Type, Method})
    add_tools!(agent, Tool(callable))
end

"""
    handle_tool_calls!(
        active_agent::Union{Agent, Nothing}, history::Vector{PT.AbstractMessage},
        context::Dict{Symbol, Any} = Dict{Symbol, Any}())

Handles tool calls for an agent.
"""
function handle_tool_calls!(
        active_agent::Union{Agent, Nothing}, history::Vector{PT.AbstractMessage},
        context::Dict{Symbol, Any} = Dict{Symbol, Any}())
    last_msg = PT.last_message(history)
    @assert PT.isaitoolrequest(last_msg) "Last message must be an AIToolsRequest! Provided: $(last_msg|>typeof)"

    isempty(last_msg.tool_calls) && return (; active_agent, history, context)
    next_agent = active_agent
    for tool in history[end].tool_calls
        if isnothing(active_agent)
            @info "Early exit: no active agent!"
            continue
        end
        name, args = tool.name, tool.args
        @info "Tool Request: $name, args: $args"
        @assert name ∈ keys(active_agent.tool_map) "Tool $name not found in agent $(active_agent.name)'s tool map."
        ## TODO: provide context where relevant! execute_tool_with_context
        ## TODO: add try-catch for function errors
        output = PT.execute_tool(active_agent.tool_map[name], args)
        ## Changing the agent
        if isabstractagent(output)
            next_agent = output
            output = JSON3.write(Dict(:assistant => next_agent.name))
        end
        tool.content = output
        @info ">> Tool Output: $(tool.content)"
        push!(history, tool)
    end
    return (; active_agent = next_agent, history, context)
end

"""
    run_full_turn(agent::Agent, messages::Vector{PT.AbstractChatMessage},
        context::Dict{Symbol, Any}; max_turns::Int = 5, kwargs...)

Runs a full turn of an agent (executes all tool calls).
"""
function run_full_turn(agent::Agent, messages::Vector{PT.AbstractChatMessage},
        context::Dict{Symbol, Any}; max_turns::Int = 5, kwargs...)
    active_agent = agent
    context = deepcopy(context)
    history = deepcopy(messages)
    init_len = length(messages)

    while (length(history) - init_len) < max_turns && !isnothing(active_agent)
        tools = collect(values(active_agent.tool_map))
        if length(history) > 1 && PT.issystemmessage(history[1])
            ## Update the system message
            history[1] = PT.SystemMessage(active_agent.instructions)
        end
        ## TODO: auto-inject variables from context if template is detected
        history = PT.aitools(history; model = active_agent.model,
            tools,
            name_user = "User", name_assistant = replace(active_agent.name, " " => "_"),
            return_all = true, verbose = false, kwargs...)
        # Print assistant response
        !isnothing(PT.last_output(history)) &&
            @info ">> Assistant: $(PT.last_output(history))"
        isempty(history[end].tool_calls) && break
        # Run tool calls
        (; active_agent, history, context) = handle_tool_calls!(
            active_agent, history, context)
    end
    return Response(;
        messages = history[init_len:end],
        agent = active_agent,
        context = context
    )
end
function run_full_turn!(session::Session; kwargs...)
    resp = run_full_turn(session.agent, session.messages, session.context; kwargs...)
    session.messages = vcat(session.messages, resp.messages)
    session.agent = resp.agent
    session.context = resp.context
    return session
end

function Session(prompt::AbstractString, agent::Agent;
        context::Dict{Symbol, Any} = Dict{Symbol, Any}())
    return Session(;
        messages = [PT.SystemMessage(agent.instructions), PT.UserMessage(prompt)],
        agent,
        context
    )
end