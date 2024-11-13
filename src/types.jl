### Flow Rules
"""
    AbstractFlowRules

Abstract type for flow control rules that manage tool usage order and prerequisites.

Two concrete implementations are provided:
- `FixedOrder`: Tools must be used in exact sequence specified
- `FixedPrerequisites`: Tools can only be used after their prerequisites

# Examples
```julia
# FixedOrder Example:
# Tools must be used in exact sequence: prepare -> process -> finish
fixed_order = FixedOrder([:prepare, :process, :finish])
# Only :prepare will be available initially
# After using :prepare, only :process will be available
# After using :process, only :finish will be available

# FixedPrerequisites Example:
# Tools can be used once their prerequisites are met
prerequisites = FixedPrerequisites([:setup, :analyze, :report])
# Initially only :setup is available
# After using :setup, both :setup and :analyze become available
# After using both :setup and :analyze, all tools become available
```
"""
abstract type AbstractFlowRules end

"""
    FixedOrder <: AbstractFlowRules

Enforces tools to be used in exact sequence specified.
Tools can only be used in the order they appear in the `tools` vector.

# Fields
- `tools::Vector{Symbol}`: Ordered sequence of tool names that must be followed

# Example
```julia
# Create agent with fixed order tools
agent = Agent(name="SequentialAgent")
add_tools!(agent, [Tool(setup), Tool(process), Tool(finish)])
fixed_order = FixedOrder([:setup, :process, :finish])
add_rules!(agent, fixed_order)

# Now tools must be used in sequence:
# 1. Only setup() is available initially
# 2. After setup(), only process() becomes available
# 3. After process(), only finish() becomes available
```
"""
Base.@kwdef struct FixedOrder <: AbstractFlowRules
    tools::Vector{Symbol}
end

"""
    FixedPrerequisites <: AbstractFlowRules

Enforces prerequisite requirements for tool usage.
A tool becomes available only after all previous tools in the sequence have been used.

# Fields
- `tools::Vector{Symbol}`: Tool names in prerequisite order

# Example
```julia
# Create agent with prerequisite-based tools
agent = Agent(name="PrereqAgent")
add_tools!(agent, [Tool(configure), Tool(analyze), Tool(report)])
prereqs = FixedPrerequisites([:configure, :analyze, :report])
add_rules!(agent, prereqs)

# Tools become available progressively:
# 1. Initially only configure() is available
# 2. After configure(), both configure() and analyze() are available
# 3. After both configure() and analyze(), all tools become available
```
"""
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

Get allowed tools considering multiple rules.
The combine function determines how to combine results from multiple rules (intersect or union).
Returns a vector of allowed tool names as strings.

# Examples
```julia
# Example: Data Pipeline with Multiple Rules
agent = Agent(name="DataScientist")
add_tools!(agent, [
    Tool(load_data),     # Load data from source
    Tool(clean_data),    # Clean and preprocess
    Tool(analyze_data),  # Perform analysis
    Tool(visualize),     # Create visualizations
    Tool(export_report)  # Generate final report
])

# Rule 1: Strict pipeline order
order_rule = FixedOrder([
    :load_data,
    :clean_data,
    :analyze_data,
    :visualize,
    :export_report
])

# Rule 2: Can't visualize or export until data is loaded and cleaned
prereq_rule = FixedPrerequisites([
    :load_data,
    :clean_data,
    :visualize,
    :export_report
])

# Add both rules to agent
add_rules!(agent, [order_rule, prereq_rule])

# Using different combine functions:

# 1. intersect (default) - tools allowed by ALL rules
# After loading data:
used = [:load_data]
allowed = get_allowed_tools([order_rule, prereq_rule], used)
# Returns ["clean_data"] - both rules agree clean_data is next

# 2. union - tools allowed by ANY rule
# After loading and cleaning:
used = [:load_data, :clean_data]
allowed = get_allowed_tools([order_rule, prereq_rule], used, combine=union)
# Returns ["analyze_data", "visualize", "export_report"]
# - order_rule allows only analyze_data
# - prereq_rule allows visualize and export_report
```

See also: [`FixedOrder`](@ref), [`FixedPrerequisites`](@ref), [`apply_rules`](@ref)
"""
function get_allowed_tools(rules::Vector{<:AbstractFlowRules}, used_tools::Vector{Symbol}; combine::Function=intersect)
    isempty(rules) && return String[]

    # Get allowed tools for each rule
    allowed_per_rule = [Set(get_allowed_tools(rule, used_tools)) for rule in rules]

    # If using union, combine allowed tools from each rule while respecting FixedOrder constraints
    if combine === union
        # Start with empty set
        allowed = Set{String}()

        # First, identify tools that would violate FixedOrder sequences
        fixed_order_rules = findall(r -> r isa FixedOrder, rules)
        excluded_tools = Set{String}()
        if !isempty(fixed_order_rules)
            for (i, rule) in enumerate(rules)
                i ∈ fixed_order_rules || continue
                # Find current position in sequence
                current_pos = 1
                while current_pos <= length(rule.tools) && rule.tools[current_pos] ∈ used_tools
                    current_pos += 1
                end
                # Exclude tools that come before current position (would violate sequence)
                for j in 1:current_pos-1
                    push!(excluded_tools, String(rule.tools[j]))
                end
            end
        end

        # Add allowed tools from each rule, excluding those that would violate FixedOrder sequences
        for (i, rule_allowed) in enumerate(allowed_per_rule)
            union!(allowed, setdiff(rule_allowed, excluded_tools))
        end
        return collect(allowed)
    else
        # For intersect (default) and other combine functions, use standard reduction
        return collect(reduce(combine, allowed_per_rule))
    end
end

"""
    apply_rules(history::AbstractVector{<:PT.AbstractMessage}, agent::Agent, tools::Vector{<:AbstractTool})

Apply flow rules to filter available tools based on usage history and rule types.
Returns a filtered vector of tools that are allowed to be used in the current turn.

# Example
```julia
# Create an ML training pipeline agent
agent = Agent(name="MLTrainer")
add_tools!(agent, [
    Tool(prepare_data),   # Data preparation
    Tool(train_model),    # Model training
    Tool(evaluate),       # Model evaluation
    Tool(deploy),         # Model deployment
    Tool(monitor)         # Model monitoring
])

# Rule 1: Must follow strict ML lifecycle
order_rule = FixedOrder([
    :prepare_data,
    :train_model,
    :evaluate,
    :deploy,
    :monitor
])

# Rule 2: Can't deploy without evaluation
prereq_rule = FixedPrerequisites([
    :evaluate,
    :deploy
])

# Add rules to agent
add_rules!(agent, [order_rule, prereq_rule])

# Create a session
session = Session(agent=agent)

# Initially only prepare_data is available
available_tools = apply_rules(session.messages, agent, collect(values(agent.tool_map)))
# Returns [Tool(prepare_data)]

# After preparing data and training
push!(session.messages, create_tool_message("prepare_data"))
push!(session.messages, create_tool_message("train_model"))
available_tools = apply_rules(session.messages, agent, collect(values(agent.tool_map)))
# Returns [Tool(evaluate)] - both rules require evaluation next
```

See also: [`get_allowed_tools`](@ref), [`get_used_tools`](@ref)
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



