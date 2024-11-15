using SwarmAgents
using PromptingTools

"""
    authenticate_user(message::String)::String

Authenticate a user with their name and email credentials.
Returns success/failure message and indicates transfer to inventory specialist.

Usage:
    authenticate_user("authenticate: John Doe, john@example.com")

Intent: Verify user identity and establish session context for further interactions.
"""
function authenticate_user(message::String)::String
    session = current_session()
    store_context = session.context[:context]::ShoeStoreContext

    if store_context.authenticated
        return "You are already authenticated as $(store_context.name)! Feel free to browse our inventory or check sizes."
    end

    name, email = process_authentication(message)
    if isnothing(name) || isnothing(email)
        return """
        Invalid authentication format.
        Please use format: authenticate: Your Name, your@email.com
        This helps us provide personalized service and track your preferences.
        """
    end

    if validate_credentials(name, email)
        store_context.authenticated = true
        store_context.name = name
        store_context.email = email
        return """
        Authentication successful! Welcome, $(name)!
        I'm transferring you to our inventory specialist who can show you our latest collection.
        They'll help you browse our complete inventory and find the perfect shoes for you.
        """
    else
        return """
        Authentication failed. Please check your credentials.
        If you're having trouble, make sure to use the exact email associated with your account.
        """
    end
end

"""
    transfer_to_inventory_specialist(message::String)::Union{Agent,Nothing}

Transfer authenticated user to the inventory specialist for product browsing.
Returns inventory agent instance or nothing if user isn't authenticated.

Usage:
    transfer_to_inventory_specialist("show me your shoes")

Intent: Ensure smooth transition to inventory browsing after successful authentication.
"""
function transfer_to_inventory_specialist(message::String)::Union{Agent,Nothing}
    session = current_session()
    store_context = session.context[:context]::ShoeStoreContext

    if !store_context.authenticated
        return nothing
    end

    return create_inventory_agent()
end

"""
Create the authentication agent with specific tools and instructions.
"""
function create_auth_agent()::Agent
    agent = Agent(;
        name = "Authentication Specialist",
        model = "gpt-4-0125-preview",  # Using gpt4o model
        instructions = """
        You are an authentication specialist for our shoe store.

        What you can do:
        - Process user authentication with name and email
        - Transfer authenticated users to the inventory specialist

        What you cannot do:
        - Show inventory or check sizes before authentication
        - Modify user credentials

        Routine:
        1. Always check if the user is trying to authenticate
        2. If authentication succeeds, transfer to inventory specialist
        3. If authentication fails, provide clear error message
        4. For non-auth requests, remind users to authenticate first

        Example authentication format:
        authenticate: Your Name, your@email.com
        """
    )

    # Add tools with clear names and docstrings
    add_tools!(agent, [
        authenticate_user,
        transfer_to_inventory_specialist
    ]; hidden_fields=["context"])  # Hide context from AI model

    return agent
end
