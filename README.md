# SwarmAgents.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://svilupp.github.io/SwarmAgents.jl/stable/) [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://svilupp.github.io/SwarmAgents.jl/dev/)
[![Build Status](https://github.com/svilupp/SwarmAgents.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/svilupp/SwarmAgents.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/svilupp/SwarmAgents.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/svilupp/SwarmAgents.jl)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

# ⚠️ Experimental Package ⚠️

**WARNING:** SwarmAgents.jl is currently in an experimental stage and is under active development. Features, APIs, and functionalities may change without notice. Use at your own risk.

## Overview
SwarmAgents.jl is a very opinionated translation of OpenAI's Swarm package. This Julia implementation leverages PromptingTools.jl to enable support for multiple LLM providers and tool calling functionalities.

## Key Features
- Integration with various LLM providers through PromptingTools.jl.
- Enhanced tool calling capabilities.
- A flexible and extensible framework for Multi-Agent systems.

## Getting Started

1. You need to have API keys for a supported LLM provider (eg, `OPENAI_API_KEY` in your environment variables). See PromptingTools.jl for more details.
2. Install the package:

```julia
using Pkg
Pkg.add(; url = "https://github.com/svilupp/SwarmAgents.jl")
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
using SwarmAgents

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

## Privacy Features

SwarmAgents.jl supports private messaging between agents through the `PrivateMessage` type and the `private` field in the `Agent` struct.

### Private Agents

You can create a private agent that will keep its messages visible only to itself:

```julia
private_agent = Agent(
    name = "PrivateAgent",
    instructions = "You are a private agent.",
    private = true  # Messages from this agent will be private
)
```

When `private = true`, all messages from this agent will be automatically wrapped in a `PrivateMessage` that is only visible to this agent.

### Message Visibility

The privacy system ensures that:
- Private messages are only visible to specified agents
- Public messages are visible to all agents
- Tool messages respect privacy settings
- Message history is filtered based on visibility

Example usage:

```julia
# Create agents
private_agent = Agent(name="PrivateAgent", private=true)
public_agent = Agent(name="PublicAgent")

# Initialize session
session = Session(private_agent)

# Private agent's messages will only be visible to itself
run_full_turn!(session, "This message will be private")

# Switch to public agent
session.agent = public_agent
# Public agent won't see private agent's messages
run_full_turn!(session, "What was the previous message?")
```

This feature is particularly valuable for:
- Keeping sensitive information private between agents
- Reducing noise in agent communications
- Maintaining a full history while only showing relevant messages to each agent
- Optimizing performance by filtering irrelevant messages

See `examples/privacy_example.jl` for a complete example of privacy features.

### Agent References

SwarmAgents.jl provides a flexible agent reference system through the `AbstractAgent` type hierarchy:
- `AbstractAgentActor`: Concrete agents that can perform actions
- `AbstractAgentRef`: References to other agents
- `AgentRef`: A simple reference to another agent by name

Example usage:

```julia
# Create agents and references
main_agent = Agent(name="MainAgent", instructions="Main agent instructions")
helper_agent = Agent(name="HelperAgent", instructions="Helper agent instructions")
helper_ref = AgentRef(name="HelperAgent")

# Initialize session with agent map
session = Session(main_agent)
add_agent!(session, helper_agent)

# Use reference to find actual agent
found_agent = find_agent(session.agent_map, helper_ref)  # Returns helper_agent
```

This feature enables:
- Flexible agent relationships and handoffs
- Indirect agent references without direct coupling
- Dynamic agent resolution during execution

### Flow Rules and Termination Checks

SwarmAgents.jl includes a sophisticated flow control system with termination checks to prevent infinite loops and detect problematic patterns:

```julia
# Create termination checks
checks = [
    TerminationCycleCheck(3, 3),  # Detect 3 repetitions of cycles up to length 3
    TerminationRepeatCheck(5),    # Detect 5 consecutive uses of the same tool
    TerminationGenericCheck((h, a) -> length(h) > 10 ? nothing : a)  # Custom check
]

# Using FixedOrder for individual tools or tool sequences
tool_rules = [
    FixedOrder(Tool(my_tool)),  # Single tool always available
    FixedOrder(order=["tool1", "tool2"]),  # Sequence of tools
]
```

**Important Notes**:
- Flow rules and termination checks operate on the complete message history, ignoring PrivateMessage visibility restrictions. This ensures proper flow control even when some messages are private.
- When using individual tools, wrap them with `FixedOrder(tool)` to make them always available in the tool sequence.
- Tool execution is handled directly through the agent's tool_map, ensuring efficient and straightforward tool access.

See `examples/flow_rules_example.jl` for flow control examples.

See folder `examples/` for more examples.
