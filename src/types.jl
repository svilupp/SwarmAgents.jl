### Flow Rules
abstract type AbstractFlowRules end

Base.@kwdef struct FixedOrder <: AbstractFlowRules
    tools::Vector{Symbol}
end

Base.@kwdef struct FixedPrerequisites <: AbstractFlowRules
    tools::Vector{Symbol}
end

FixedOrder(tools::Vector{String}) = FixedOrder(Symbol.(tools))
FixedPrerequisites(tools::Vector{String}) = FixedPrerequisites(Symbol.(tools))

### Agent Types
abstract type AbstractAgent end
isabstractagent(x) = x isa AbstractAgent

"""
    Agent

Agent is a stateless struct that holds the the reference to LLM, tools and the instructions.

# Fields
- `name::String`: The name of the agent.
- `model::String`: The model to use for the agent.
- `instructions::String`: The instructions for the agent.
- `tool_map::Dict{String, AbstractTool}`: A dictionary of tools available to the agent.
- `tool_choice::Union{String, Nothing}`: The tool choice for the agent.
- `parallel_tool_calls::Bool`: Whether to allow parallel tool calls. Defaults to `true` - NOT SUPPORTED YET.
- `rules::Vector{AbstractFlowRules}`: Flow rules that control tool usage order and prerequisites.
"""
Base.@kwdef struct Agent <: AbstractAgent
    name::String = "Agent"
    model::String = "gpt-4o"
    instructions::String = "You are a helpful agent."
    tool_map::Dict{String, AbstractTool} = Dict()
    tool_choice::Union{String, Nothing} = nothing
    parallel_tool_calls::Bool = true
    rules::Vector{AbstractFlowRules} = AbstractFlowRules[]
end
function Base.show(io::IO, t::AbstractAgent)
    print(io, t.name, " (Tools: ", length(t.tool_map), ")")
end

scrub_agent_name(agent::Agent) = replace(agent.name, " " => "_")
function update_model(agent::Agent, model::String)
    return Agent(; [f => getfield(agent, f) for f in fieldnames(Agent)]..., model)
end

"""
    Session

Session is a mutable struct that holds the `messages`, `agent` and `context`.

# Fields
- `messages::Vector{PT.AbstractMessage}`: The history of chat or tool messages in the session.
- `agent::Union{Agent, Nothing}`: The current active agent in the session.
- `context::Dict{Symbol, Any}`: The context variables or other data in the session.
"""
Base.@kwdef mutable struct Session
    messages::Vector = PT.AbstractMessage[]
    agent::Union{Agent, Nothing} = nothing
    context::Dict{Symbol, Any} = Dict{Symbol, Any}()
end
function Base.show(io::IO, t::Session)
    agent_str = isnothing(t.agent) ? "None" : t.agent.name
    print(io, "Session (Messages: ", length(t.messages), ", Agent: ", agent_str, ")")
end

"""
    Response

Response from a single full turn of swarm.

# Fields
- `messages::Vector{PT.AbstractMessage}`: The additional messages from the last full turn.
- `agent::Union{Agent, Nothing}`: The current active agent in the session.
- `context::Dict{Symbol, Any}`: The context variables or other data in the session.
"""
Base.@kwdef struct Response
    messages::Vector = PT.AbstractMessage[]
    agent::Union{Agent, Nothing} = nothing
    context::Dict{Symbol, Any} = Dict{Symbol, Any}()
end
Base.show(io::IO, t::Response) = dump(io, t; maxdepth = 1)

### Tools
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

### Flow Rules Management

"""
    add_rules!(agent::Agent, rules::Vector{<:AbstractFlowRules})

Adds flow rules to an agent. Flow rules control the order and prerequisites of tool usage.
"""
function add_rules!(agent::Agent, rules::Vector{<:AbstractFlowRules})
    for rule in rules
        add_rules!(agent, rule)
    end
end

"""
    add_rules!(agent::Agent, rule::AbstractFlowRules)

Adds a single flow rule to an agent.
"""
function add_rules!(agent::Agent, rule::AbstractFlowRules)
    # Validate that all tools in the rule exist in the agent's tool map
    for tool in rule.tools
        tool_name = String(tool)
        @assert tool_name ∈ keys(agent.tool_map) "Tool $tool_name not found in agent $(agent.name)'s tool map."
    end
    push!(agent.rules, rule)
end

"""
    get_used_tools(history::AbstractVector{<:PT.AbstractMessage})

Extract the list of tools that have been used from the message history.
Returns a vector of tool names as symbols.
"""
function get_used_tools(history::AbstractVector{<:PT.AbstractMessage})
    used_tools = Symbol[]
    for msg in history
        if PT.isaitoolrequest(msg)
            for tool in PT.tool_calls(msg)
                push!(used_tools, Symbol(tool.name))
            end
        end
    end
    return used_tools
end

"""
    get_allowed_tools(rule::AbstractFlowRules, used_tools::Vector{Symbol}; kwargs...)

Get allowed tools for a specific rule type.
Returns a vector of allowed tool names as strings.
"""
function get_allowed_tools(rule::FixedOrder, used_tools::Vector{Symbol})
    # If no tools used, only first tool is allowed
    if isempty(used_tools)
        return [String(first(rule.tools))]
    end

    # Find the last used tool in the sequence
    last_idx = findlast(t -> t ∈ used_tools, rule.tools)
    if isnothing(last_idx)
        # If no tool from sequence was used, start with first
        return [String(first(rule.tools))]
    elseif last_idx < length(rule.tools)
        # Allow next tool in sequence
        return [String(rule.tools[last_idx + 1])]
    end
    return String[]
end

function get_allowed_tools(rule::FixedPrerequisites, used_tools::Vector{Symbol})
    allowed = String[]
    for (i, tool) in enumerate(rule.tools)
        if i == 1 || all(t -> t ∈ used_tools, rule.tools[1:i-1])
            push!(allowed, String(tool))
        end
    end
    return allowed
end

"""
    get_allowed_tools(rules::Vector{<:AbstractFlowRules}, used_tools::Vector{Symbol}; combine::Function=intersect)

Get allowed tools for multiple rules. Combines results using the specified function (default: intersect).
Returns a vector of allowed tool names as strings.
"""
function get_allowed_tools(rules::Vector{<:AbstractFlowRules}, used_tools::Vector{Symbol}; combine::Function=intersect)
    isempty(rules) && return String[]

    # Get allowed tools for first rule
    allowed = Set(get_allowed_tools(first(rules), used_tools))

    # Combine with remaining rules
    for rule in rules[2:end]
        allowed = combine(allowed, Set(get_allowed_tools(rule, used_tools)))
    end

    return collect(allowed)
end

"""
    apply_rules(history::AbstractVector{<:PT.AbstractMessage}, agent::Agent, tools::Vector{<:AbstractTool})

Apply flow rules to filter available tools based on usage history and rule types.
Returns a filtered vector of tools that are allowed to be used in the current turn.
"""
function apply_rules(history::AbstractVector{<:PT.AbstractMessage}, agent::Agent, tools::Vector{<:AbstractTool})
    isempty(agent.rules) && return tools

    # Get used tools from history
    used_tools = get_used_tools(history)

    # Get allowed tools based on rules
    allowed_tools = get_allowed_tools(agent.rules, used_tools)

    # Return only tools that are allowed by the rules
    return filter(t -> t.name ∈ allowed_tools, tools)
end



"""
    get_allowed_tools(rules::Vector{<:AbstractFlowRules}, used_tools::Vector{Symbol}; combine::Function=intersect)

Get allowed tools for multiple rules. Combines results using the specified function (default: intersect).
Returns a vector of allowed tool names as strings.
"""
# Removed duplicate implementation

"""
    apply_rules(history::AbstractVector{<:PT.AbstractMessage}, agent::Agent, tools::Vector{<:AbstractTool})

Apply flow rules to filter available tools based on usage history and rule types.
Returns a filtered vector of tools that are allowed to be used in the current turn.
"""
# Removed duplicate implementation
