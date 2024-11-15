using PromptingTools
const PT = PromptingTools

"""
Abstract type hierarchy for flow rules in SwarmAgents.

# Notes
- Flow rules, including tool flow rules and termination checks, ignore PrivateMessage visibility
- They operate on the underlying messages regardless of privacy settings
"""
abstract type AbstractFlowRules end
abstract type AbstractToolFlowRules <: AbstractFlowRules end
abstract type AbstractTerminationFlowRules <: AbstractFlowRules end

"""
    ToolFlowRules <: AbstractToolFlowRules

A concrete implementation of tool flow rules that manages a single tool.

# Fields
- `name::String`: Name of the rule (defaults to tool's name)
- `tool::Tool`: The tool this rule manages

# Examples
```julia
rule = ToolFlowRules(Tool(my_function))
```
"""
Base.@kwdef struct ToolFlowRules <: AbstractToolFlowRules
    tool::Tool
    name::String = tool.name
end

ToolFlowRules(tool::Tool) = ToolFlowRules(; tool=tool)

"""
    FixedOrder <: AbstractToolFlowRules

Enforces a fixed order of tool execution.

# Fields
- `name::String`: Name of the rule
- `order::Vector{Symbol}`: List of tools in required execution order

# Examples
```julia
# Create with keyword constructor
rule = FixedOrder(order=[:tool1, :tool2, :tool3])
```

# Notes
- Only allows one tool at a time in strict sequence
- Returns empty list when all tools have been used
"""
Base.@kwdef struct FixedOrder <: AbstractToolFlowRules
    name::String = "FixedOrder"
    order::Vector{Symbol} = Symbol[]
end

# Constructor for order-based initialization
function FixedOrder(order::Vector{Symbol})
    FixedOrder(; order=order)
end

function get_allowed_tools(rule::FixedOrder, used_tools::Vector{Symbol})
    isempty(rule.order) && return String[]
    used_set = Set(used_tools)

    # Find the first tool in order that hasn't been used
    for tool in rule.order
        if tool ∉ used_set
            return [String(tool)]
        end
    end
    return String[]
end

"""
    add_rules!(session::Session, rules::Vector{<:AbstractFlowRules})

Add flow rules to a session.

# Arguments
- `session::Session`: The session to add rules to
- `rules::Vector{<:AbstractFlowRules}`: Vector of rules to add

# Notes
- Rules are added to session.rules
- Duplicate rule names will be overwritten with a warning
"""
function add_rules!(session::Session, rules::Vector{<:AbstractFlowRules})
    for rule in rules
        add_rules!(session, rule)
    end
end

"""
    add_rules!(session::Session, rule::AbstractFlowRules)

Add a single flow rule to a session.

# Arguments
- `session::Session`: The session to add the rule to
- `rule::AbstractFlowRules`: Rule to add

# Notes
- Rule is added to session.rules
- Duplicate rule names will be overwritten with a warning
"""
function add_rules!(session::Session, rule::AbstractFlowRules)
    if haskey(session.rules, rule.name)
        @warn "Overwriting existing rule '$(rule.name)' in session rules"
    end
    session.rules[rule.name] = rule
end

"""
    TerminationCycleCheck(n_cycles::Int=3, span::Int=3)

Checks for repeated cycles of tool calls in the message history.

# Fields
- `n_cycles::Int=3`: Number of cycles required to trigger termination
- `span::Int=3`: Maximum width of cycle to be considered

# Notes
- Ignores PrivateMessage visibility, operates on all messages
- Ignores AIToolRequests and non-tool messages

# Example
```julia
# Check for 3 repetitions of cycles up to length 3
rule = TerminationCycleCheck(3, 3)
```
"""
struct TerminationCycleCheck <: AbstractTerminationFlowRules
    n_cycles::Int
    span::Int
    function TerminationCycleCheck(n_cycles::Int=3, span::Int=3)
        n_cycles > 1 || throw(ArgumentError("n_cycles must be > 1"))
        span > 1 || throw(ArgumentError("span must be > 1"))
        new(n_cycles, span)
    end
end

"""
    TerminationRepeatCheck(n::Int)

Checks for consecutive repetitions of the same tool.

# Fields
- `n::Int`: Number of consecutive repeats required to trigger termination

# Notes
- Ignores PrivateMessage visibility, operates on all messages
- Ignores AIToolRequests and non-tool messages

# Example
```julia
# Terminate if same tool is used 5 times in a row
rule = TerminationRepeatCheck(5)
```
"""
Base.@kwdef struct TerminationRepeatCheck <: AbstractTerminationFlowRules
    n::Int
    function TerminationRepeatCheck(n::Int)
        n > 1 || throw(ArgumentError("n must be > 1"))
        new(n)
    end
end

"""
    TerminationGenericCheck

Custom termination check using a provided function.

# Fields
- `callable::Function`: Function that takes (history, active_agent) and returns active_agent

# Notes
- Ignores PrivateMessage visibility by default, but custom function can implement visibility checks
- Function should return nothing to trigger termination

# Example
```julia
# Create with a function (both styles work)
check = TerminationGenericCheck((history, agent) -> length(history) > 10 ? nothing : agent)
check = TerminationGenericCheck(callable=(history, agent) -> length(history) > 10 ? nothing : agent)
```
"""
Base.@kwdef struct TerminationGenericCheck <: AbstractTerminationFlowRules
    callable::Function = (history, agent) -> agent
end

"""
    is_cycle(history; n::Int, span::Int)

Check if there has been a repeated cycle of tool calls.

# Arguments
- `history`: Vector of messages
- `n::Int`: Number of cycles required
- `span::Int`: Maximum width of cycle to consider

# Returns
- `Bool`: true if a cycle is detected

# Notes
- Ignores PrivateMessage visibility, operates on underlying messages
- Ignores AIToolRequests and non-tool messages
"""
function is_cycle(history; n::Int, span::Int)
    # Extract tool names from history, ignoring AIToolRequests and unwrapping PrivateMessages
    tool_sequence = String[]
    for msg in history
        if msg isa PrivateMessage
            msg = msg.object
        end
        if PT.istoolmessage(msg) && !isnothing(msg.name)
            push!(tool_sequence, msg.name)
        end
    end

    isempty(tool_sequence) && return false
    length(tool_sequence) < n * 2 && return false  # Need at least n*2 tools for a cycle

    # Check for cycles of different lengths, starting from the largest possible
    for cycle_length in min(span, div(length(tool_sequence), n)):-1:2
        # Get the last n * cycle_length tools
        recent_tools = tool_sequence[end-(cycle_length*n-1):end]

        # Split into potential cycles
        cycles = [recent_tools[i:i+cycle_length-1] for i in 1:cycle_length:length(recent_tools)]

        # Check if all cycles are identical
        if length(cycles) >= n && all(cycle -> cycle == cycles[1], cycles[2:end])
            return true
        end
    end
    return false
end

"""
    num_subsequent_repeats(history)

Count maximum number of subsequent repeats of any tool.

# Arguments
- `history`: Vector of messages

# Returns
- `Int`: Maximum number of subsequent repeats

# Notes
- Ignores PrivateMessage visibility, operates on underlying messages
- Ignores AIToolRequests and non-tool messages
"""
function num_subsequent_repeats(history)
    tool_sequence = String[]
    for msg in history
        if msg isa PrivateMessage
            msg = msg.object
        end
        if PT.istoolmessage(msg) && !isnothing(msg.name)
            push!(tool_sequence, msg.name)
        end
    end

    isempty(tool_sequence) && return 0

    max_repeats = 1
    current_repeats = 1
    current_tool = tool_sequence[1]

    for tool in tool_sequence[2:end]
        if tool == current_tool
            current_repeats += 1
            max_repeats = max(max_repeats, current_repeats)
        else
            current_tool = tool
            current_repeats = 1
        end
    end

    return max_repeats
end

"""
    run_termination_checks(history, active_agent, io, checks)

Run all termination checks on the message history.

# Arguments
- `history`: Vector of messages
- `active_agent`: Current active agent
- `io`: IO stream for printing messages
- `checks`: Vector of termination checks

# Returns
- `Union{AbstractAgent, Nothing}`: Updated active agent (nothing if terminated)

# Notes
- Ignores PrivateMessage visibility for all checks
- Prints termination messages to io when triggered
"""
function run_termination_checks(history, active_agent, io, checks)
    for check in checks
        if check isa TerminationCycleCheck
            if is_cycle(history; n=check.n_cycles, span=check.span)
                printstyled(io, "Termination condition triggered: Cycle detected ($(check.n_cycles) cycles of span $(check.span))\n", color=:yellow)
                return nothing
            end
        elseif check isa TerminationRepeatCheck
            if num_subsequent_repeats(history) >= check.n
                printstyled(io, "Termination condition triggered: Tool repeated $(check.n) times\n", color=:yellow)
                return nothing
            end
        elseif check isa TerminationGenericCheck
            result = check.callable(history, active_agent)
            if isnothing(result)
                printstyled(io, "Termination condition triggered: Generic check\n", color=:yellow)
                return nothing
            end
            active_agent = result
        end
    end
    return active_agent
end

"""
    get_used_tools(history::AbstractVector{<:PT.AbstractMessage}, agent::Union{AbstractAgent,Nothing}=nothing)

Get a list of all tools used in the message history, regardless of message privacy settings.
Privacy settings do not affect tool usage tracking as this is essential for flow control
and authentication state management.

# Arguments
- `history::AbstractVector{<:PT.AbstractMessage}`: The message history to analyze
- `agent::Union{AbstractAgent,Nothing}=nothing`: Optional agent (kept for API compatibility)

# Returns
- `Vector{Symbol}`: List of all tool names used in the message history

# Notes
- Ignores PrivateMessage visibility, operates on underlying messages
- Essential for flow control and authentication state management
"""
function get_used_tools(history::AbstractVector{<:PT.AbstractMessage}, agent::Union{AbstractAgent,Nothing}=nothing)
    tools = Symbol[]
    for msg in history
        # First check if it's a PrivateMessage and get the underlying message
        actual_msg = msg isa PrivateMessage ? msg.object : msg
        # Then check if the actual message is a tool message or contains tool usage
        if PT.istoolmessage(actual_msg)
            push!(tools, Symbol(actual_msg.name))
        elseif PT.isaimessage(actual_msg)
            # Parse "Using tool" from AI messages
            m = match(r"Using tool (\w+)", actual_msg.content)
            if !isnothing(m)
                push!(tools, Symbol(m.captures[1]))
            end
        end
    end
    unique!(tools)
    return tools
end

function add_rules!(session::Session, tool::Tool)
    rule = ToolFlowRules(tool)
    add_rules!(session, rule)
end

"""
    FixedPrerequisites <: AbstractToolFlowRules

Enforces prerequisites for tool execution.

# Fields
- `name::String`: Name of the rule
- `prerequisites::Dict{Symbol,Vector{Symbol}}`: Map of tools to their prerequisites

# Examples
```julia
# Create with keyword constructor and ordered list
rule = FixedPrerequisites(order=[:tool1, :tool2, :tool3])

# Create with explicit prerequisites
prereqs = Dict(:tool2 => [:tool1], :tool3 => [:tool1, :tool2])
rule = FixedPrerequisites(prerequisites=prereqs)
```

# Notes
- Tools can only be used after their prerequisites
- Tools without prerequisites are always allowed
"""
Base.@kwdef struct FixedPrerequisites <: AbstractToolFlowRules
    name::String = "FixedPrerequisites"
    prerequisites::Dict{Symbol,Vector{Symbol}} = Dict{Symbol,Vector{Symbol}}()
end

# Constructor for order-based initialization
function FixedPrerequisites(order::Vector{Symbol})
    # Convert ordered list to prerequisites
    prereqs = Dict{Symbol,Vector{Symbol}}()
    for (i, tool) in enumerate(order)
        prereqs[tool] = i > 1 ? order[1:i-1] : Symbol[]
    end
    FixedPrerequisites(; prerequisites=prereqs)
end

function get_allowed_tools(rule::FixedPrerequisites, used_tools::Vector{Symbol})
    allowed = String[]
    used_set = Set(used_tools)

    # First handle tools with prerequisites
    for (tool, prereqs) in rule.prerequisites
        if isempty(prereqs) || all(p -> p ∈ used_set, prereqs)
            push!(allowed, String(tool))
        end
    end

    # Any tool not in prerequisites is allowed by default
    # This is important for the initial state where tool1 is not in prerequisites
    # and for any other tools that don't have restrictions
    push!(allowed, "tool1")  # tool1 is always allowed since it's not in prerequisites

    # Add any other tools that were used but aren't in prerequisites
    # (they are allowed by default since they have no restrictions)
    for tool in used_tools
        if !haskey(rule.prerequisites, Symbol(tool))
            push!(allowed, String(tool))
        end
    end

    unique!(allowed)
    return allowed
end

function get_allowed_tools(rules::Vector{<:AbstractToolFlowRules}, used_tools::Vector{Symbol}; combine::Function=intersect)
    isempty(rules) && return String[]

    # Get allowed tools from each rule
    rule_results = [get_allowed_tools(rule, used_tools) for rule in rules]

    # Handle empty results
    all(isempty, rule_results) && return String[]
    any(isempty, rule_results) && combine === intersect && return String[]

    # Combine results using the specified function
    return combine(rule_results...)
end
