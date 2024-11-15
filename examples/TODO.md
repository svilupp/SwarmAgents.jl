# Examples Refactoring Todo List

## Shoe Store Bot Example
- [ ] Remove OpenAI mocking, use ENV API key
- [ ] Simplify tool definitions (use function names only)
- [ ] Add clear function names and docstrings
- [ ] Implement reflection/handover messages
- [ ] Add hidden_fields for context
- [ ] Use gpt4o model
- [ ] Update agent instructions
- [ ] Implement agent handoffs (authentication -> inventory -> sizing)
- [ ] Add transfer_to_xyz tools

## Required Changes Per Tool
### Authentication Agent
- [ ] authenticate_user (clear name, docstring)
- [ ] transfer_to_inventory (handoff tool)

### Inventory Agent
- [ ] show_inventory (clear name, docstring)
- [ ] transfer_to_sizing (handoff tool)

### Sizing Agent
- [ ] check_size (clear name, docstring)
- [ ] recommend_size (optional enhancement)

## General Updates
- [ ] Update all agents to use gpt4o model
- [ ] Implement proper context handling with hidden_fields
- [ ] Add clear agent instructions for each specialized agent
- [ ] Ensure proper handover messages between agents
