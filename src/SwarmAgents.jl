module SwarmAgents

# All imports centralized here
using JSON3
using PromptingTools
const PT = PromptingTools
using PromptingTools: AbstractMessage, SystemMessage, UserMessage, AIToolRequest, ToolMessage
using PromptingTools: AbstractTool, isabstracttool, Tool
using PromptingTools: tool_calls, execute_tool, parse_tool, tool_call_signature

# Abstract types
include("abstract_types.jl")
export AbstractAgent, AbstractAgentActor, AbstractAgentRef,
    AbstractFlowRules, AbstractToolFlowRules, AbstractTerminationFlowRules

# Core types (agent, session)
include("core_types.jl")
export Agent, Session, isabstractagent, isabstractagentref, isabstractagentactor, add_rules!

# Utilities (shared functions)
include("utils.jl")
export print_progress, scrub_agent_name, convert_message

# Privacy functionality
include("privacy.jl")
export PrivateMessage, is_visible, filter_history, maybe_private_message

# Flow rules (termination and tool selection)
include("flow_rules.jl")
export TerminationCycleCheck, TerminationRepeatCheck, TerminationGenericCheck,
    is_cycle, num_subsequent_repeats, run_termination_checks, get_used_tools

# Workflow (run_full_turn, handle tool calls)
include("workflow.jl")
export run_full_turn, run_full_turn!, Response, add_tools!

end # module
