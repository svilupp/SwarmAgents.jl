using PromptingTools
const PT = PromptingTools

"""
Abstract type hierarchy for flow rules in SwarmAgents.

# Type Hierarchy
- AbstractFlowRules
  - AbstractToolFlowRules: Rules for controlling tool execution order and availability
  - AbstractTerminationFlowRules: Rules for determining when to terminate execution

# Notes
- Flow rules, including termination checks, ignore PrivateMessage visibility
- They operate on the underlying messages regardless of privacy settings
"""

"""
    get_allowed_tools(rules::Vector{<:AbstractFlowRules}, used_tools::Vector{String}, all_tools::Vector{String}; combine::Function=union)

Get the list of allowed tools based on flow rules and usage history.

# Arguments
- `rules::Vector{<:AbstractFlowRules}`: Vector of flow rules to apply
- `used_tools::Vector{String}`: List of tools that have been used
- `all_tools::Vector{String}`: Complete set of available tools
- `combine::Function=union`: Function to combine results from multiple rules (default: union for OR behavior)

# Returns
- `Vector{String}`: List of allowed tool names

# Notes
- Only processes rules that are subtypes of AbstractToolFlowRules
- If no tool rules are present, returns all_tools (passthrough)
- Empty result from a rule means no tools allowed by that rule
- Results are combined using union by default (OR behavior)
"""

"""
    get_allowed_tools(rules::Vector{<:AbstractFlowRules}, used_tools::Vector{String}, all_tools::Vector{String}; combine::Function=union)

Get the list of allowed tools based on flow rules and usage history.

# Arguments
- `rules::Vector{<:AbstractFlowRules}`: Vector of flow rules to apply
- `used_tools::Vector{String}`: List of tools that have been used
- `all_tools::Vector{String}`: Complete set of available tools
- `combine::Function=union`: Function to combine results from multiple rules (default: union for OR behavior)

# Returns
- `Vector{String}`: List of allowed tool names

# Notes
- Only processes rules that are subtypes of AbstractToolFlowRules
- If no tool rules are present, returns all_tools (passthrough)
- Empty result from a rule means no tools allowed by that rule
- Results are combined using union by default (OR behavior)
"""
function get_allowed_tools(rules::Vector{<:AbstractFlowRules}, used_tools::Vector{String}, all_tools::Vector{String}; combine::Function=union)
    # Filter for tool rules only
    tool_rules = filter(r -> r isa AbstractToolFlowRules, rules)

    # If no tool rules, return all_tools in their original order
    isempty(tool_rules) && return copy(all_tools)

    # Check for FixedOrder rules first
    fixed_order_rules = filter(r -> r isa FixedOrder, tool_rules)
    if !isempty(fixed_order_rules)
        # Get allowed tools from FixedOrder rules
        fixed_order_results = [
            get_allowed_tools(rule, used_tools, all_tools)
            for rule in fixed_order_rules
        ]
        # Filter out empty results
        valid_fixed_results = filter(!isempty, fixed_order_results)

        # If any FixedOrder rule returns tools, use only those tools
        if !isempty(valid_fixed_results)
            # Take the first non-empty result from FixedOrder rules
            return first(valid_fixed_results)
        end
    end

    # If no FixedOrder rules or they return empty, process other rules
    other_rules = filter(r -> !(r isa FixedOrder), tool_rules)
    if isempty(other_rules)
        return String[]
    end

    # Get allowed tools from other rules
    rule_results = [
        get_allowed_tools(rule, used_tools, all_tools)
        for rule in other_rules
    ]

    # Filter out empty results
    valid_results = filter(!isempty, rule_results)
    isempty(valid_results) && return String[]

    # Combine results using the provided function
    if combine == intersect
        # For intersect, we want tools that appear in all results
        combined = collect(reduce(intersect, Set.(valid_results)))
        # Maintain original order from all_tools
        return filter(t -> t ∈ combined && t ∈ all_tools, all_tools)
    else
        # For union/vcat, maintain order while deduplicating
        seen = Set{String}()
        result = String[]
        for tools in valid_results
            for tool in tools
                if tool ∉ seen && tool ∈ all_tools
                    push!(seen, tool)
                    push!(result, tool)
                end
            end
        end
        return result
    end
end

"""
    FixedOrder <: AbstractToolFlowRules

A concrete implementation of AbstractToolFlowRules that enforces a fixed order of tool execution.
Controls tool availability based on execution sequence.

# Fields
- `name::String`: Name of the rule
- `order::Vector{String}`: List of tools in required execution order

# Examples
```julia
# Single tool (always available as first in cycle)
rule = FixedOrder(tool)  # Convenience constructor for single tool

# Multiple tools in sequence
tools = [tool1, tool2, tool3]
rules = [FixedOrder(tool) for tool in tools]  # Broadcast FixedOrder over tools
add_rules!(session, rules)  # Add as flow rules

# Create with explicit order
rule = FixedOrder(["tool1", "tool2", "tool3"])
```

# Notes
- Only allows one tool at a time in strict sequence
- Returns empty list when all tools have been used
- If order is empty, returns all_tools (passthrough)
- Single tool constructor makes the tool always available (first in cycle)
"""
Base.@kwdef struct FixedOrder <: AbstractToolFlowRules
    name::String = "FixedOrder"
    order::Vector{String} = String[]
end

# Constructors for FixedOrder
function FixedOrder(order::Vector{String})
    FixedOrder(; order=order)
end

# Convenience constructor for single tool
function FixedOrder(tool::Tool)
    FixedOrder(; order=[tool.name])
end

function get_allowed_tools(rule::FixedOrder, used_tools::Vector{String}, all_tools::Vector{String}; combine::Function=union)
    isempty(rule.order) && return all_tools

    # Filter tools that exist in all_tools first
    valid_tools = filter(t -> t ∈ all_tools, rule.order)
    isempty(valid_tools) && return String[]

    # If no tools have been used, start with the first valid tool
    if isempty(used_tools)
        return [valid_tools[1]]
    end

    # Find the last used tool from our sequence
    last_used_idx = 0
    for (i, tool) in enumerate(valid_tools)
        if tool ∈ used_tools
            last_used_idx = i
        end
    end

    # If we haven't used any tools from our sequence, return the first one
    if last_used_idx == 0
        return [valid_tools[1]]
    end

    # If we've used all tools in sequence, return empty
    if last_used_idx == length(valid_tools)
        return String[]
    end

    # Return the next tool in sequence
    return [valid_tools[last_used_idx + 1]]
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
    append!(session.rules, rules)
end

"""
    add_rules!(session::Session, rule::AbstractFlowRules)

Add a single flow rule to a session.

# Arguments
- `session::Session`: The session to add the rule to
- `rule::AbstractFlowRules`: Rule to add

# Notes
- Rule is added to session.rules vector
"""
function add_rules!(session::Session, rule::AbstractFlowRules)
    push!(session.rules, rule)
end

# Removed add_rules! for tools vector - users should use FixedOrder directly
# Example: add_rules!(session, [FixedOrder(tool) for tool in tools])

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
    name::String = "TerminationRepeatCheck"
    n::Int
    function TerminationRepeatCheck(n::Int)
        n > 1 || throw(ArgumentError("n must be > 1"))
        new("TerminationRepeatCheck", n)
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
    name::String = "TerminationGenericCheck"
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
- `Vector{String}`: List of all tool names used in the message history

# Notes
- Only extracts tool names from AIToolRequest messages' tool_calls
- Ignores PrivateMessage visibility, operates on underlying messages
- Essential for flow control and authentication state management
"""
function get_used_tools(history::AbstractVector{<:PT.AbstractMessage}, agent::Union{AbstractAgent,Nothing}=nothing)
    tools = String[]
    for msg in history
        # First check if it's a PrivateMessage and get the underlying message
        actual_msg = msg isa PrivateMessage ? msg.object : msg
        # Extract tool names only from AIToolRequest tool_calls
        if actual_msg isa PT.AIToolRequest
            for tool_call in actual_msg.tool_calls
                push!(tools, tool_call.name)
            end
        end
    end
    return tools
end

# Removed add_rules! for single tool - users should use FixedOrder directly
# Example: add_rules!(session, FixedOrder(tool))

"""
    FixedPrerequisites <: AbstractToolFlowRules

A concrete implementation of AbstractToolFlowRules that enforces prerequisites for tool execution.
Controls tool availability based on prerequisite completion.

# Fields
- `name::String`: Name of the rule
- `prerequisites::Dict{String,Vector{String}}`: Map of tools to their prerequisites

# Examples
```julia
# Create with keyword constructor and ordered list
rule = FixedPrerequisites(order=["search", "analyze", "summarize"])

# Create with explicit prerequisites
prereqs = Dict("analyze" => ["search"], "summarize" => ["search", "analyze"])
rule = FixedPrerequisites(prerequisites=prereqs)
```

# Notes
- Tools can only be used after their prerequisites
- Tools without prerequisites are always allowed
"""
Base.@kwdef struct FixedPrerequisites <: AbstractToolFlowRules
    name::String = "FixedPrerequisites"
    prerequisites::Dict{String,Vector{String}} = Dict{String,Vector{String}}()
end

# Constructor for order-based initialization
function FixedPrerequisites(order::Vector{String})
    # Convert ordered list to prerequisites
    prereqs = Dict{String,Vector{String}}()
    for (i, tool) in enumerate(order)
        prereqs[tool] = i > 1 ? order[1:i-1] : String[]
    end
    FixedPrerequisites(; prerequisites=prereqs)
end

function get_allowed_tools(rule::FixedPrerequisites, used_tools::Vector{String}, all_tools::Vector{String}; combine::Function=union)
    # If no prerequisites defined, return all available tools
    isempty(rule.prerequisites) && return all_tools

    # Create set of used tools for efficient lookup
    used_set = Set(used_tools)
    allowed = String[]

    # Check each tool in all_tools
    for tool in all_tools
        # Get prerequisites for this tool (empty if none defined)
        prereqs = get(rule.prerequisites, tool, String[])

        # Only include tool if all its prerequisites are in all_tools
        if all(prereq -> prereq ∈ all_tools, prereqs)
            # Then check if all prerequisites have been used
            if isempty(prereqs) || all(prereq -> prereq ∈ used_set, prereqs)
                push!(allowed, tool)
            end
        end
    end

    return allowed
end
