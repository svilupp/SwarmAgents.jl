```@meta
CurrentModule = SwarmAgents
```

# SwarmAgents.jl

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

## Flow Rules and Tool Control

Flow rules control how tools are executed in your agent system. They determine which tools are available at any given time and in what order they should be executed.

### Flow Rule Types

SwarmAgents supports different types of flow rules:
- `AbstractToolFlowRules`: Base type for all tool-related flow rules
- `FixedOrder`: Controls tool execution order (replaces deprecated ToolFlowRules)
- `FixedPrerequisites`: Enforces tool prerequisites (coming soon)

Note: The `ToolFlowRules` type has been removed in favor of using `FixedOrder` directly, which provides clearer semantics and better control over tool execution order.

### Tool Execution Order

You can control tool execution using `FixedOrder`:

```julia
# Make a single tool always available (first in cycle)
agent = Agent(name="MyAgent", instructions="Test agent")
add_tools!(agent, my_tool)
add_rules!(session, FixedOrder(my_tool))  # Convenience constructor for single tool

# Control execution order of multiple tools
tools = [tool1, tool2, tool3]
rules = [FixedOrder(tool) for tool in tools]  # Broadcast FixedOrder over tools
add_rules!(session, rules)  # Add rules to enforce tool order
```

### Tool Filtering and Combination

The `run_full_turn` function supports controlling how tools from multiple rules are combined:

```julia
# Default behavior uses union (removes duplicates)
response = run_full_turn(agent, messages, session)

# Use vcat to preserve tool order and duplicates (recommended for sequential tool execution)
response = run_full_turn(agent, messages, session; combine=vcat)
```

Why use `vcat`? When you have multiple rules that might reference the same tool in different positions, `vcat` preserves both the order and duplicates, ensuring tools execute in the exact sequence you specified. For example:

```julia
# Create rules that use the same tool in different positions
rules = [
    FixedOrder(["validate", "process"]),      # First sequence
    FixedOrder(["process", "validate"])       # Second sequence
]

# With union (default), you lose the intended sequence:
# get_allowed_tools(rules, [], all_tools) → ["validate", "process"]

# With vcat, you preserve the exact sequence:
# get_allowed_tools(rules, [], all_tools; combine=vcat) → ["validate", "process", "process", "validate"]
```

### Tool Availability Rules

Tools are filtered using `get_allowed_tools`, which determines available tools based on:
- Current flow rules (must be subtypes of AbstractToolFlowRules)
- Previously used tools (tracking tool usage history)
- All available tools in the agent's tool map (passed as all_tools argument)

```julia
# Get all tool names from agent
all_tools = String[string(name) for name in keys(agent.tool_map)]

# Get allowed tools based on rules and history
allowed_tools = get_allowed_tools(session.rules, used_tools, all_tools)

# Use custom combine function for multiple rules
allowed_tools = get_allowed_tools(session.rules, used_tools, all_tools; combine=vcat)
```

If no tool rules are present, all agent tools are available (passthrough behavior).

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
