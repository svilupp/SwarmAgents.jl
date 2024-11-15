using SwarmAgents
using PromptingTools

"""
Check if a specific shoe size is available.
Returns availability status and suggestions for alternatives if needed.
"""
function check_size(message::String)::String
    session = current_session()
    store_context = session.context[:context]::ShoeStoreContext

    if !store_context.authenticated
        return "Please authenticate first."
    end

    size_match = match(r"(?i)(?:check size|size)\s+(\d+)\s+(.*)", message)
    if isnothing(size_match)
        return """
        I couldn't understand the size request.
        Please specify like this: 'check size 9 Running Shoes' or 'size 10 Casual Sneakers'
        """
    end

    size = parse(Int, size_match[1])
    shoe = size_match[2]

    if !haskey(SHOE_INVENTORY, shoe)
        return """
        I couldn't find that shoe model.
        Available models:
        $(join(keys(SHOE_INVENTORY), ", "))
        """
    end

    available = is_size_available(shoe, size)
    response = available ?
        "Good news! Size $size is available for $shoe!" :
        "Sorry, size $size is not available for $shoe."

    # Add available sizes information
    available_sizes = SHOE_INVENTORY[shoe]["sizes"]
    response *= "\nAvailable sizes for $shoe: $(join(available_sizes, ", "))"

    return response
end

"""
Create the sizing specialist agent with specific tools and instructions.
"""
function create_sizing_agent()::Agent
    agent = Agent(;
        name = "Sizing Specialist",
        model = "gpt-4-0125-preview",  # Using gpt4o model
        instructions = """
        You are a sizing specialist for our shoe store.

        What you can do:
        - Check availability of specific shoe sizes
        - Provide information about available sizes
        - Suggest alternatives when requested size isn't available

        What you cannot do:
        - Process authentication
        - Modify inventory
        - Process orders

        Routine:
        1. When asked about a size, check availability
        2. Always provide complete size range information
        3. If size unavailable, suggest checking other sizes
        4. Be precise and helpful in responses

        Example queries:
        - "check size 9 Running Shoes"
        - "size 10 Casual Sneakers"
        """
    )

    # Add tools with clear names and docstrings
    add_tools!(agent, [
        check_size
    ]; hidden_fields=["context"])  # Hide context from AI model

    return agent
end
