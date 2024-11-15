# # Triage Agent Example

# Necessary imports
using SwarmAgents
using PromptingTools
const PT = PromptingTools
using JSON3
using Dates

# # Define the tools
# Let's define some tools that the agents can use.

"""
Refund an item. Make sure you have the item_id of the form item_... Ask for user confirmation before processing the refund.
"""
function process_refund(item_id::String, reason::String)
    println("[mock] Refunding item $item_id because $reason...")
    return "Success!"
end

"""
Apply a discount to the user's cart.
"""
function apply_discount()
    println("[mock] Applying discount...")
    return "Applied discount of 11%"
end

# # Define the agents
# Instructions are very important! They give the agent its "purpose" and "personality".
# Also, instructions are the way to define ROUTINES for the agent (procedures to follow).

triage_agent = Agent(
    name = "Triage Agent",
    instructions = "Determine which agent is best suited to handle the user's request, and transfer the conversation to that agent."
)
sales_agent = Agent(
    name = "Sales Agent",
    instructions = "Be super enthusiastic about selling bees."
)
refunds_agent = Agent(
    name = "Refunds Agent",
    instructions = "Help the user with a refund. If the reason is that it was too expensive, offer the user a refund code. If they insist, then process the refund.",
    tool_map = PT.tool_call_signature([process_refund, apply_discount])
)

## Enable agents to hand-off to other agents
"""
Call this function if a user is asking about a topic that is not handled by the current agent.
"""
transfer_back_to_triage() = triage_agent

transfer_to_sales() = sales_agent

transfer_to_refunds() = refunds_agent

# Add the tools to the agents
add_tools!(triage_agent, [transfer_to_sales, transfer_to_refunds])
add_tools!(sales_agent, transfer_back_to_triage)
add_tools!(refunds_agent, transfer_back_to_triage)

# # Option 1: Run the process manually

current_agent = triage_agent
conv = PT.create_template(;
    user = "I want to buy a bee.", system = current_agent.instructions)
num_iter = 0
while true && num_iter <= 10
    conv = PT.aitools(conv; model = "gpt4o",
        tools = collect(values(current_agent.tool_map)),
        name_user = "User", name_assistant = replace(current_agent.name, " " => "_"),
        return_all = true, verbose = false)
    # Print assistant response
    !isnothing(PT.last_output(conv)) && @info ">> Assistant: $(PT.last_output(conv))"
    # Terminate if no further tool calls
    isempty(conv[end].tool_calls) && break
    for tool in conv[end].tool_calls
        name, args = tool.name, tool.args
        @info "Tool Request: $name, args: $args"
        output = PT.execute_tool(current_agent.tool_map, tool)
        ## Changing the agent
        if isabstractagent(output)
            current_agent = output
            ## Swap the SystemMessage = instructions with the current agent's instructions
            popfirst!(conv)
            pushfirst!(conv, PT.SystemMessage(current_agent.instructions))
            output = JSON3.write(Dict(:assistant => current_agent.name))
        end
        tool.content = output
        @info ">> Tool Output: $(tool.content)"
        push!(conv, tool)
    end
    num_iter += 1
end

# # Simpler API with Session
# Initialize a session to hold the state and allow repeated turns
sess = Session(triage_agent)
# Run a full turn until tools are depleted
run_full_turn!(sess, "I want to buy a bee.")

# Follow-ups
run_full_turn!(sess, "I bought one and it stung me! Refund me!")