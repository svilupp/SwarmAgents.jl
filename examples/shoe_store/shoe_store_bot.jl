using SwarmAgents

"""
Example of a shoe store customer service bot with authentication using SwarmAgents.jl
This bot demonstrates:
1. Authentication flow with name/email validation
2. Pre-authentication message interception
3. Protected actions after authentication
4. Session state persistence
"""

# Define our shoe inventory (in a real application, this would be in a database)
const SHOE_INVENTORY = Dict(
    "Running Shoes" => Dict("sizes" => [7, 8, 9, 10, 11], "price" => 89.99),
    "Casual Sneakers" => Dict("sizes" => [8, 9, 10], "price" => 59.99),
    "Hiking Boots" => Dict("sizes" => [7, 8, 9, 10], "price" => 129.99)
)

# Authentication details (in a real application, this would be in a secure database)
const VALID_USERS = Dict(
    "jan svilupp" => "jan@svilupp.github.com"
)

# Define our conversation flow rules with authentication
struct ShoeStoreFlowRules <: AbstractFlowRules end

"""
Initialize the context with authentication state
"""
function initialize_context()
    Dict(
        "authenticated" => false,
        "name" => nothing,
        "email" => nothing,
        "cart" => String[]
    )
end

"""
Validate authentication credentials
"""
function validate_credentials(name::String, email::String)
    lowercase_name = lowercase(name)
    if haskey(VALID_USERS, lowercase_name)
        return VALID_USERS[lowercase_name] == email
    end
    return false
end

"""
Check if size is available for a shoe
"""
function is_size_available(shoe::String, size::Int)
    haskey(SHOE_INVENTORY, shoe) && size in SHOE_INVENTORY[shoe]["sizes"]
end

"""
Format shoe information
"""
function format_shoe_info(shoe::String)
    info = SHOE_INVENTORY[shoe]
    "$(shoe): \$$(info["price"]) - Available sizes: $(join(info["sizes"], ", "))"
end

"""
Process authentication attempt from message
"""
function process_authentication(msg::String)
    # Try to extract name and email from message
    # Format expected: "authenticate: Name, email@example.com"
    auth_match = match(r"(?i)authenticate:\s*([^,]+),\s*([^\s]+@[^\s]+)", msg)
    if isnothing(auth_match)
        return nothing, nothing
    end
    return strip(auth_match[1]), strip(auth_match[2])
end

"""
Process user message and update context accordingly
"""
function SwarmAgents.process_message(rules::ShoeStoreFlowRules, message::String, context::Dict)
    # Handle authentication first
    if !context["authenticated"]
        # Check if this is an authentication attempt
        if contains(lowercase(message), "authenticate:")
            name, email = process_authentication(message)
            if isnothing(name) || isnothing(email)
                return """
                Invalid authentication format.
                Please use format: authenticate: Your Name, your@email.com
                """
            end

            if validate_credentials(name, email)
                context["authenticated"] = true
                context["name"] = name
                context["email"] = email
                return """
                Authentication successful! Welcome, $(name)!
                You can now:
                - View our inventory: "show shoes"
                - Check size availability: "check size 9 Running Shoes"
                - Get help: "help"
                """
            else
                return "Authentication failed. Please check your credentials."
            end
        else
            return """
            Please authenticate first using:
            authenticate: Your Name, your@email.com
            """
        end
    end

    # Process authenticated user messages
    msg = lowercase(message)

    # Show inventory
    if contains(msg, "show") && contains(msg, "shoe")
        return "Available shoes:\n" * join([format_shoe_info(shoe) for shoe in keys(SHOE_INVENTORY)], "\n")

    # Check size availability
    elseif contains(msg, "check size")
        size_match = match(r"check size (\d+) (.*)", message)
        if isnothing(size_match)
            return "Please specify size and shoe name (e.g., 'check size 9 Running Shoes')"
        end

        size = parse(Int, size_match[1])
        shoe = size_match[2]

        if !haskey(SHOE_INVENTORY, shoe)
            return "Shoe model not found. Use 'show shoes' to see available models."
        end

        if is_size_available(shoe, size)
            return "Size $size is available for $shoe!"
        else
            return "Sorry, size $size is not available for $shoe."
        end

    # Help message
    elseif contains(msg, "help")
        return """
        I can help you with:
        - Viewing our inventory: "show shoes"
        - Checking size availability: "check size 9 Running Shoes"
        - Getting help: "help"
        """

    # Default response
    else
        return "I'm not sure how to help with that. Try asking for 'help' to see what I can do."
    end
end

# Example usage:
function run_example()
    # Initialize the bot with our rules and context
    bot = Agent(
        ShoeStoreFlowRules(),
        initialize_context()
    )

    # Example conversation
    println("Bot: Welcome to our shoe store! Please authenticate first.")

    println("\nUser: show shoes")
    println("Bot: ", bot("show shoes"))

    println("\nUser: authenticate: Jan Svilupp, jan@svilupp.github.com")
    println("Bot: ", bot("authenticate: Jan Svilupp, jan@svilupp.github.com"))

    println("\nUser: show shoes")
    println("Bot: ", bot("show shoes"))

    println("\nUser: check size 9 Running Shoes")
    println("Bot: ", bot("check size 9 Running Shoes"))
end

# Run the example if this file is run directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_example()
end
