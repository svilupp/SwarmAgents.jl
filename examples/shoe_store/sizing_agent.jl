using SwarmAgents
using PromptingTools

"""
    check_size_availability(message::String)::String

Check if a specific shoe size is available and provide alternatives.
Returns availability status, complete size range, and helpful suggestions.

Usage:
    check_size_availability("check size 9 Running Shoes")
    check_size_availability("size 10 Casual Sneakers")

Intent: Help customer find their perfect size and provide alternatives if needed.
"""
function check_size_availability(message::String)::String
    session = current_session()
    store_context = session.context[:context]::ShoeStoreContext

    if !store_context.authenticated
        return "Please authenticate first to check size availability."
    end

    size_match = match(r"(?i)(?:check size|size)\s+(\d+)\s+(.*)", message)
    if isnothing(size_match)
        return """
        I couldn't understand your size request.
        To help you better, please specify like this:
        - 'check size 9 Running Shoes'
        - 'size 10 Casual Sneakers'
        This helps me find exactly what you're looking for!
        """
    end

    size = parse(Int, size_match[1])
    shoe = size_match[2]

    if !haskey(SHOE_INVENTORY, shoe)
        return """
        I couldn't find that shoe model in our collection.
        Here are our available models:
        $(join(keys(SHOE_INVENTORY), ", "))
        Would you like to check size availability for any of these?
        """
    end

    available = is_size_available(shoe, size)
    response = available ?
        "Great news! Size $size is available for $shoe! Would you like to know more about this model?" :
        "I apologize, but size $size is not currently available for $shoe."

    # Add available sizes information and suggestions
    available_sizes = SHOE_INVENTORY[shoe]["sizes"]
    response *= "\n\nComplete size range for $shoe: $(join(available_sizes, ", "))"

    if !available
        response *= "\n\nWould you like to check availability in a different size or perhaps look at similar styles?"
    end

    return response
end

"""
    transfer_back_to_inventory(message::String)::Tuple{Agent,String}

Transfer customer back to inventory specialist for browsing more shoes.
Returns inventory agent instance and handover message.

Usage:
    transfer_back_to_inventory("show me other shoes")

Intent: Allow smooth transition back to inventory browsing when customer wants to explore more options.
"""
function transfer_back_to_inventory(message::String)::Tuple{Agent,String}
    session = current_session()
    store_context = session.context[:context]::ShoeStoreContext

    # Create handover message for smooth transition
    handover_message = """
    Transferring you back to our Inventory Specialist.
    Customer Details:
    - Name: $(store_context.name)
    - Email: $(store_context.email)
    - Previous Action: Size check completed

    They'll help you explore more options!
    """

    # Create and return the inventory specialist agent
    inventory_agent = create_inventory_agent()
    inventory_agent.context = session.context

    return (inventory_agent, handover_message)
end

"""
Create the sizing specialist agent with specific tools and instructions.
"""
function create_sizing_agent()::Agent
    agent = Agent(;
        name = "Sizing Specialist",
        model = "gpt4o",  # Use OpenAI GPT-4 model
        instructions = """
        You are a sizing specialist for our shoe store.

        What you can do:
        - Check availability of specific shoe sizes
        - Provide information about available sizes
        - Suggest alternatives when requested size isn't available
        - Transfer back to inventory specialist when needed

        What you cannot do:
        - Process authentication
        - Modify inventory
        - Process orders

        Routine:
        1. When asked about a size, check availability
        2. Always provide complete size range information
        3. If size unavailable, suggest checking other sizes
        4. When customer wants to see other shoes, transfer back to inventory
        5. Be precise and helpful in responses

        Example queries:
        - "check size 9 Running Shoes"
        - "size 10 Casual Sneakers"
        - "show me other shoes" (will transfer back to inventory)
        """
    )

    # Add tools with clear names and docstrings
    add_tools!(agent, [
        check_size_availability,
        transfer_back_to_inventory
    ]; hidden_fields=["context"])  # Hide context from AI model

    return agent
end
