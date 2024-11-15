module SwarmAgents

# All imports centralized here
using JSON3
using PromptingTools
const PT = PromptingTools
using PromptingTools: AbstractMessage, SystemMessage, UserMessage, AIMessage, ToolMessage
using PromptingTools: AbstractTool, isabstracttool, Tool, istoolmessage, isaimessage, isusermessage, issystemmessage, isaitoolrequest
using PromptingTools: tool_calls, execute_tool, parse_tool, tool_call_signature
# Note: ToolCall is accessed via PT.ToolCall

# Abstract types
include("abstract_types.jl")
export AbstractAgent, AbstractAgentActor, AbstractAgentRef,
    AbstractFlowRules, AbstractToolFlowRules, AbstractTerminationFlowRules

# Core types (agent, session)
include("core_types.jl")
export Agent, AgentRef, Session, isabstractagent, isabstractagentref, isabstractagentactor, add_rules!, add_agent!, find_agent

# Utilities (shared functions)
include("utils.jl")
export print_progress, scrub_agent_name, convert_message, update_system_message!

# Privacy functionality
include("privacy.jl")
export PrivateMessage, is_visible, filter_history, maybe_private_message

# Flow rules (termination and tool selection)
include("flow_rules.jl")
export TerminationCycleCheck, TerminationRepeatCheck, TerminationGenericCheck, ToolFlowRules,
    FixedOrder, FixedPrerequisites, is_cycle, num_subsequent_repeats, run_termination_checks, get_used_tools,
    get_allowed_tools

# Workflow (run_full_turn, handle tool calls)
include("workflow.jl")
export run_full_turn, run_full_turn!, Response, add_tools!, handle_tool_calls!, add_transfers!, transfer_agent

end # module
