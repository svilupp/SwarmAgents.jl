module SwarmAgents

using JSON3
using PromptingTools
const PT = PromptingTools
using PromptingTools: AbstractTool, isabstracttool, Tool
using PromptingTools: tool_calls, execute_tool, parse_tool, tool_call_signature

export Agent, Session, Response, isabstractagent, add_rules!, PrivateMessage, is_visible, filter_history, wrap_message
include("types.jl")

export add_tools!, run_full_turn!, run_full_turn, get_used_tools
include("utils.jl")

include("privacy.jl")
include("tools.jl")

end # module
