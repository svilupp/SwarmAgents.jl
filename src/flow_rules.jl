using PromptingTools
using PromptingTools: AbstractMessage

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
# Custom termination check
check = (history, agent) -> length(history) > 10 ? nothing : agent
rule = TerminationGenericCheck(check)
```
"""
struct TerminationGenericCheck <: AbstractTerminationFlowRules
    callable::Function
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

export AbstractFlowRules, AbstractToolFlowRules, AbstractTerminationFlowRules,
    TerminationCycleCheck, TerminationRepeatCheck, TerminationGenericCheck,
    is_cycle, num_subsequent_repeats, run_termination_checks
