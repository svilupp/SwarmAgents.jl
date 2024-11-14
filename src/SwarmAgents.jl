module SwarmAgents

# All imports centralized here
using JSON3
using PromptingTools
const PT = PromptingTools
using PromptingTools: AbstractMessage, SystemMessage, UserMessage, AIToolRequest, ToolMessage
using PromptingTools: AbstractTool, isabstracttool, Tool
using PromptingTools: tool_calls, execute_tool, parse_tool, tool_call_signature

# Core types (abstract types, agent, session)
include("core_types.jl")
export AbstractAgent, AbstractAgentActor, AbstractAgentRef, Agent, Session,
    isabstractagent, isabstractagentref, isabstractagentactor

# Utilities (shared functions)
include("utils.jl")
export print_progress, scrub_agent_name, convert_message,
    add_tools!, add_rules!

# Privacy functionality
include("privacy.jl")
export PrivateMessage, is_visible, filter_history, maybe_private_message

# Flow rules (termination and tool selection)
include("flow_rules.jl")
export AbstractFlowRules, AbstractToolFlowRules, AbstractTerminationFlowRules,
    TerminationCycleCheck, TerminationRepeatCheck, TerminationGenericCheck,
    is_cycle, num_subsequent_repeats, run_termination_checks

# Workflow (run_full_turn, handle tool calls)
include("workflow.jl")
export run_full_turn, run_full_turn!, Response

# Tools functionality
include("tools.jl")
export get_used_tools

end # module
