module SwarmAgents

using JSON3
using PromptingTools
const PT = PromptingTools
using PromptingTools: AbstractTool, isabstracttool, Tool
using PromptingTools: tool_calls, execute_tool, parse_tool, tool_call_signature

# First include agent_types.jl which defines AbstractAgent types
include("agent_types.jl")

# Then include types.jl which uses Agent type
include("types.jl")

# Include other functionality
include("message_utils.jl")
include("agent_management.jl")
include("utils.jl")
include("flow_rules.jl")
include("privacy.jl")
include("tools.jl")

# Export all public interfaces
export Agent, Session, Response, add_rules!, add_tools!
export AbstractAgent, AgentRef,
    isabstractagentref, isabstractagentactor,
    find_agent, add_agent!
export PrivateMessage, is_visible, filter_history, maybe_private_message
export add_tools!, run_full_turn!, run_full_turn, get_used_tools
export AbstractFlowRules, AbstractToolFlowRules, AbstractTerminationFlowRules,
    TerminationCycleCheck, TerminationRepeatCheck, TerminationGenericCheck,
    is_cycle, num_subsequent_repeats, run_termination_checks

end # module
