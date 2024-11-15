using SwarmAgents
using PromptingTools

"""
    display_available_inventory(message::String)::String

Show complete inventory of available shoes with sizes and prices.
Returns formatted list of all available shoes with suggestions for next steps.

Usage:
    display_available_inventory("show me your shoes")

Intent: Provide comprehensive overview of available products and guide to size checking.
"""
function display_available_inventory(message::String)::String
    session = current_session()
    store_context = session.context[:context]::ShoeStoreContext

    if !store_context.authenticated
        return "Please authenticate first to view our exclusive collection."
    end

    return """
    Here's our current collection, $(store_context.name):
    $(join([format_shoe_info(shoe) for shoe in keys(SHOE_INVENTORY)], "\n"))

    Would you like to check if your size is available in any of these models?
    I can connect you with our sizing specialist who can help you find the perfect fit.
    Just let me know which shoe and size you're interested in!
    """
end

"""
    transfer_to_sizing_specialist(message::String)::Union{Agent,Nothing}

Transfer customer to sizing specialist for detailed size availability checks.
Returns sizing agent instance or nothing if user isn't authenticated.

Usage:
    transfer_to_sizing_specialist("check size 9 Running Shoes")

Intent: Ensure smooth transition to size checking when customer shows specific interest.
"""
function transfer_to_sizing_specialist(message::String)::Union{Agent,Nothing}
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
        model = "gpt4o",  # Use OpenAI GPT-4 model
        instructions = """
        You are an inventory specialist for our shoe store.

        What you can do:
        - Show complete inventory with prices and available sizes
        - Transfer customers to sizing specialist for specific size checks
        - Receive customers back from sizing specialist
        - Provide detailed product information

        What you cannot do:
        - Process authentication
        - Modify inventory
        - Process specific size checks directly

        Routine:
        1. When asked about inventory, show complete list
        2. If customer asks about specific sizes, transfer to sizing specialist
        3. When receiving customer back from sizing, suggest other options
        4. Always be helpful and suggest next steps
        5. Maintain professional and friendly tone

        Example queries:
        - "show shoes" or "show inventory"
        - "what shoes do you have?"
        - "check size 9" (will transfer to sizing specialist)
        """
    )

    # Add tools with clear names and docstrings
    add_tools!(agent, [
        display_available_inventory,
        transfer_to_sizing_specialist
    ]; hidden_fields=["context"])  # Hide context from AI model

    return agent
end
