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

SwarmAgents supports different types of flow rules that inherit from `AbstractToolFlowRules`:
- `FixedOrder`: Controls tool execution order, allowing you to specify a sequence of tools to be executed
- `FixedPrerequisites`: Enforces tool prerequisites, ensuring tools are only available after their prerequisites are met

Both `FixedOrder` and `FixedPrerequisites` are subtypes of `AbstractToolFlowRules`, providing consistent behavior for tool filtering and execution control.

### Tool Execution Order

You can control tool execution using either `FixedOrder` or `FixedPrerequisites`:

```julia
# Make a single tool always available
agent = Agent(name="MyAgent", instructions="Test agent")
add_tools!(agent, my_tool)
session = Session(agent)
add_rules!(session, FixedOrder(string(my_tool.name)))  # Single tool wrapped in FixedOrder

# Control execution order of multiple tools
rules = [FixedOrder(["tool1", "tool2"]), FixedOrder(["tool3", "tool4"])]
add_rules!(session, rules)  # Pass vector of rules directly
```

### Tool Filtering and Error Handling

The `get_allowed_tools` function determines which tools are available based on your flow rules and ensures tools exist in the agent's tool map. If a requested tool is not found, a `ToolNotFoundError` will be raised:

```julia
# Tools must exist in agent's tool_map
response = run_full_turn(agent, messages, session)
# If a tool is not found, ToolNotFoundError is raised
```

### Tool Output Handling

Tools can return any arbitrary struct as output. The system processes tool output in this order:
1. If output is an AbstractString, use it directly
2. Look for the `:output` property if available
3. Use the `show` method for any other type

To customize output handling for your structs, either:
- Define an `:output` property that returns an AbstractString
- Implement a custom `show` method for your type

Example:
```julia
struct CustomTool
    output::String
end

# Will automatically use the output property
my_tool = CustomTool("Hello")

# Or implement show method
struct AnotherTool
    data::Any
end
Base.show(io::IO, t::AnotherTool) = print(io, "Tool output: $(t.data)")
```

### Tool Availability and Deduplication

Tools are filtered using `get_allowed_tools`, which:
1. Ensures tools exist in agent's tool_map (all_tools argument)
2. Removes duplicates while preserving order
3. Applies flow rule constraints

```julia
# Get allowed tools based on rules and history
allowed_tools = get_allowed_tools(session.rules, used_tools, all_tools)

# Note: get_allowed_tools always deduplicates tools to ensure each tool
# appears only once in the final sequence
```

If no rules are present, all agent tools are available (passthrough behavior).

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
