using Swarm
using PromptingTools
const PT = PromptingTools
using Dates
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

english_agent = Agent(name = "English Agent", instructions = "You only speak English.")
spanish_agent = Agent(name = "Spanish Agent", instructions = "You only speak Spanish.")

struct TransferToSpanishAgent <: AbstractTool end
function (t::TransferToSpanishAgent)()
    return spanish_agent
end
push!(english_agent.functions, TransferToSpanishAgent)

struct TellDate <: AbstractTool end
function (t::TellDate)()
    return "The date is $(Dates.today())"
end
push!(english_agent.functions, TellDate)

struct TellTime <: AbstractTool end
function (t::TellTime)()
    return "The time is $(Dates.now())"
end
push!(english_agent.functions, TellTime)

struct TransferToEnglishAgent <: AbstractTool end
function (t::TransferToEnglishAgent)()
    return english_agent
end
push!(spanish_agent.functions, TransferToEnglishAgent)

schema, datastructtype = PT.function_call_signature(TransferToSpanishAgent; strict = false)
schema, datastructtype = PT.function_call_signature(TellTime; strict = false)

msg = aiextract("Hello, what is the time?"; return_type = [TellTime, TellDate])
msg.content

## TODO: fix empty init 