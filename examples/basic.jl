using Swarm
using PromptingTools
const PT = PromptingTools
using JSON3
using Dates

# # Example 1: Date manipulation and Bday wishes

"""
Returns the current date.
"""
function tell_date()
    return "The date is $(Dates.today())"
end

"Returns the current time"
function tell_time()
    return "The time is $(Dates.format(Dates.now(), "HH:MM:SS"))"
end

"""
Returns a happy birthday message.
"""
function wish_happy_birthday(name::String, age::Int)
    return "Wish should be: Happy $(age)th birthday, $(name)!"
end

## Run full turn (until tool calls are exhausted)
tool_map = PT.tool_call_signature([tell_date, tell_time, wish_happy_birthday])
conv = "Hello, my cousin Joe was born on $(Dates.today() - Year(10)). Is there anything I should know?"
num_iter = 0
while true && num_iter <= 10
    conv = aitools(conv;
        tools = collect(values(tool_map)), return_all = true, verbose = false)
    # Print assistant response
    !isnothing(PT.last_output(conv)) && @info ">> Assistant: $(PT.last_output(conv))"
    # Terminate if no further tool calls
    isempty(conv[end].tool_calls) && break
    for tool in conv[end].tool_calls
        name, args = tool.name, tool.args
        @info "Tool Request: $name, args: $args"
        tool.content = PT.execute_tool(tool_map[name], args)
        @info ">> Tool Output: $(tool.content)"
        push!(conv, tool)
    end
    num_iter += 1
end

# # Example 2: Routing to other agents

# from swarm import Swarm, Agent

# client = Swarm()

# english_agent = Agent(
#     name="English Agent",
#     instructions="You only speak English.",
# )

# spanish_agent = Agent(
#     name="Spanish Agent",
#     instructions="You only speak Spanish.",
# )

# def transfer_to_spanish_agent():
#     """Transfer spanish speaking users immediately."""
#     return spanish_agent

# english_agent.functions.append(transfer_to_spanish_agent)

# messages = [{"role": "user", "content": "Hola. ¿Como estás?"}]
# response = client.run(agent=english_agent, messages=messages)

# print(response.messages[-1]["content"])

english_agent = Agent(name = "English Agent",
    instructions = "You are a helpful customer support agent. You only speak English.")
spanish_agent = Agent(name = "Spanish Agent",
    instructions = "You are a helpful customer support agent. You only speak Spanish.")

"""Transfer spanish speaking users immediately."""
transfer_to_spanish_agent() = spanish_agent
add_tools!(english_agent, transfer_to_spanish_agent)
"""Transfer english speaking users immediately."""
transfer_to_english_agent() = english_agent
add_tools!(spanish_agent, transfer_to_english_agent)

current_agent = english_agent
conv = PT.create_template(;
    user = "Hola. ¿Como estás?", system = current_agent.instructions)
num_iter = 0
while true && num_iter <= 5
    conv = PT.aitools(conv;
        tools = collect(values(current_agent.tool_map)), return_all = true, verbose = false)
    # Print assistant response
    !isnothing(PT.last_output(conv)) && @info ">> Assistant: $(PT.last_output(conv))"
    # Terminate if no further tool calls
    isempty(conv[end].tool_calls) && break
    for tool in conv[end].tool_calls
        name, args = tool.name, tool.args
        @info "Tool Request: $name, args: $args"
        output = PT.execute_tool(current_agent.tool_map[name], args)
        ## Changing the agent
        if isabstractagent(output)
            current_agent = output
            popfirst!(conv)
            pushfirst!(conv, PT.SystemMessage(current_agent.instructions))
            output = "Transferred to $(current_agent.name). Adopt the persona immediately."
        end
        tool.content = output
        @info ">> Tool Output: $(tool.content)"
        push!(conv, tool)
    end
    num_iter += 1
end