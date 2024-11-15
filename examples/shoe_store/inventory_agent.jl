using SwarmAgents
using PromptingTools

"""
Show the complete inventory of available shoes with sizes and prices.
Returns formatted list of all available shoes.
"""
function show_inventory(message::String)::String
    session = current_session()
    store_context = session.context[:context]::ShoeStoreContext

    if !store_context.authenticated
        return "Please authenticate first."
    end

    return """
    Here's our current inventory, $(store_context.name):
    $(join([format_shoe_info(shoe) for shoe in keys(SHOE_INVENTORY)], "\n"))

    Would you like to check any specific sizes? I can transfer you to our sizing specialist.
    """
end

"""
Transfer to the sizing specialist for detailed size checks.
Returns the sizing agent instance for handling size queries.
"""
function transfer_to_sizing(message::String)::Union{Agent,Nothing}
    session = current_session()
    store_context = session.context[:context]::ShoeStoreContext

    if !store_context.authenticated
        return nothing
    end

    return create_sizing_agent()
end

"""
Create the inventory agent with specific tools and instructions.
"""
function create_inventory_agent()::Agent
    agent = Agent(;
        name = "Inventory Specialist",
        model = "gpt-4-0125-preview",  # Using gpt4o model
        instructions = """
        You are an inventory specialist for our shoe store.

        What you can do:
        - Show complete inventory with prices and available sizes
        - Transfer customers to sizing specialist for specific size checks

        What you cannot do:
        - Process authentication
        - Modify inventory
        - Process specific size checks directly

        Routine:
        1. When asked about inventory, show complete list
        2. If customer asks about specific sizes, transfer to sizing specialist
        3. Always be helpful and suggest next steps
        4. Maintain professional and friendly tone

        Example queries:
        - "show shoes" or "show inventory"
        - "what shoes do you have?"
        """
    )

    # Add tools with clear names and docstrings
    add_tools!(agent, [
        show_inventory,
        transfer_to_sizing
    ]; hidden_fields=["context"])  # Hide context from AI model

    return agent
end
