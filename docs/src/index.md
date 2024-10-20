```@meta
CurrentModule = Swarm
```

# Swarm.jl

# ⚠️ Experimental Package ⚠️

**WARNING:** Swarm.jl is currently in an experimental stage and is under active development. Features, APIs, and functionalities may change without notice. Use at your own risk.

## Overview
Swarm.jl is a very opinionated translation of OpenAI's Swarm package. This Julia implementation leverages PromptingTools.jl to enable support for multiple LLM providers and tool calling functionalities.

## Key Features
- Integration with various LLM providers through PromptingTools.jl.
- Enhanced tool calling capabilities.
- A flexible and extensible framework for Multi-Agent systems.

## Getting Started

1. You need to have API keys for a supported LLM provider (eg, `OPENAI_API_KEY` in your environment variables). See PromptingTools.jl for more details.
2. Install the package:

```julia
using Pkg
Pkg.add(; url = "https://github.com/svilupp/Swarm.jl")
```

## Key Concepts

This implementation mostly follows the [OpenAI Swarm](https://github.com/openai/swarm) package.
It might be helpful to read the original cookbook on [orchestrating agents](https://cookbook.openai.com/examples/orchestrating_agents).

### Routines

A routine is a set of instructions for an AI agent to follow, like a recipe.

**Example:** A customer service routine
1. Understand the problem
2. Suggest a solution or transfer to a specialized agent
3. Offer a refund if needed

### Handoffs

A handoff occurs when one AI agent passes the conversation to another specialized agent.

**Example:** Customer support system
- Triage Agent → directs to appropriate department
- Sales Agent ← handles purchases
- Repair Agent ← manages product issues

Handoffs allow seamless transitions between different expertise areas, enhancing the overall interaction.

## Usage

```julia
using Swarm

## Define agents and their tools
# Instructions are the routines
english_agent = Agent(name = "English Agent",
    instructions = "You only speak English.")
spanish_agent = Agent(name = "Spanish Agent",
    instructions = "You only speak Spanish.")

# Below are the handoffs
transfer_to_spanish_agent() = spanish_agent
add_tools!(english_agent, transfer_to_spanish_agent)

transfer_to_english_agent() = english_agent
add_tools!(spanish_agent, transfer_to_english_agent)

# Initialize a session to hold the state and pick the initial agent
sess = Session(english_agent)

# Run a full turn until tools are depleted
run_full_turn!(sess, "Hola. ¿Como estás?")

# You can run repeated turns to continue the session
run_full_turn!(sess, "What do you mean?")
```

```plaintext
>> User: Hola. ¿Como estás?

>> Tool Request: transfer_to_spanish_agent, args: Dict{Symbol, Any}()
>> Tool Output: {"assistant":"Spanish Agent"}
>> Assistant: ¡Hola! Estoy bien, gracias. ¿Y tú?

>> User: What do you mean?

>> Tool Request: transfer_to_english_agent, args: Dict{Symbol, Any}()
>> Tool Output: {"assistant":"English Agent"}
>> Assistant: You were speaking in Spanish, so I transferred you to a Spanish-speaking agent. How can I assist you in English today?
```


See folder `examples/` for more examples.