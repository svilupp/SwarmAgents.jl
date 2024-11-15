using SwarmAgents
using SwarmAgents: Tool
using PromptingTools
const PT = PromptingTools

# Verify OpenAI API key is available for PromptingTools
if !haskey(ENV, "OPENAI_API_KEY")
    error("OpenAI API key not found in environment variables")
end

using Dates

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

"""
Context structure for the shoe store bot
"""
Base.@kwdef mutable struct ShoeStoreContext
    authenticated::Bool = false
    name::Union{String, Nothing} = nothing
    email::Union{String, Nothing} = nothing
    cart::Vector{String} = String[]
end

"""
Session context wrapper for type safety
"""
Base.@kwdef mutable struct ShoeStoreSessionContext
    context::ShoeStoreContext
end

"""
Convert ShoeStoreSessionContext to Dict format required by SwarmAgents.Session
"""
function to_session_dict(ctx::ShoeStoreSessionContext)::Dict{Symbol,Any}
    Dict{Symbol,Any}(:context => ctx.context)
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

# Session management
const CURRENT_SESSION = Ref{Union{Nothing,Session}}(nothing)

function current_session()::Session
    if isnothing(CURRENT_SESSION[])
        error("No active session. Please initialize a session first.")
    end
    CURRENT_SESSION[]
end

function set_current_session!(session::Session)
    CURRENT_SESSION[] = session
end

# Parameter structures for tools
# Message argument structures for PromptingTools compatibility

"""
    AuthArgs

Arguments for authentication tool.

# Fields
- `message::String`: The authentication message containing name and email
"""
Base.@kwdef struct AuthArgs
    message::String
end

"""
    ShowArgs

Arguments for showing inventory tool.

# Fields
- `message::String`: Optional message (defaults to empty string)
"""
Base.@kwdef struct ShowArgs
    message::String = ""  # Default empty string as this tool doesn't need a message
end

"""
    SizeArgs

Arguments for checking size availability tool.

# Fields
- `message::String`: The size check message containing shoe type and size
"""
Base.@kwdef struct SizeArgs
    message::String
end

# Core parameter structures
Base.@kwdef struct AuthenticateParams
    msg::String
    context::ShoeStoreSessionContext
end

Base.@kwdef struct ShowInventoryParams
    context::ShoeStoreSessionContext
end

Base.@kwdef struct CheckSizeParams
    msg::String
    context::ShoeStoreSessionContext
end

Base.@kwdef struct CheckSizeParams
    msg::String
    context::ShoeStoreSessionContext
end

"""
    authenticate(params::AuthenticateParams)::String

Authenticate user with provided credentials.

# Arguments
- `params.msg::String`: Message containing authentication details
- `params.context::SessionContext`: Session context

# Returns
- `String`: Authentication result message
"""
function authenticate(params::AuthenticateParams)::String
    if params.context.context.authenticated
        return "You are already authenticated as $(params.context.context.name)!"
    end

    name, email = process_authentication(params.msg)
    if isnothing(name) || isnothing(email)
        return """
        Invalid authentication format.
        Please use format: authenticate: Your Name, your@email.com
        """
    end

    if validate_credentials(name, email)
        params.context.context.authenticated = true
        params.context.context.name = name
        params.context.context.email = email
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
end

"""
    show_inventory(params::ShowInventoryParams)::String

Show available shoe inventory.

# Arguments
- `params.context::SessionContext`: Session context

# Returns
- `String`: Formatted inventory list
"""
function show_inventory(params::ShowInventoryParams)::String
    if !params.context.context.authenticated
        return "Please authenticate first using: authenticate: Your Name, your@email.com"
    end
    return "Available shoes:\n" * join([format_shoe_info(shoe) for shoe in keys(SHOE_INVENTORY)], "\n")
end

"""
    check_size(params::CheckSizeParams)::String

Check if a specific shoe size is available.

# Arguments
- `params.msg::String`: Message containing size and shoe details
- `params.context::SessionContext`: Session context

# Returns
- `String`: Size availability message
"""
function check_size(params::CheckSizeParams)::String
    if !params.context.context.authenticated
        return "Please authenticate first using: authenticate: Your Name, your@email.com"
    end

    size_match = match(r"check size (\d+) (.*)", params.msg)
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
end

# Create wrapper functions that handle parameter construction
"""
    wrapped_authenticate(message::String)::String

Tool function to authenticate users.

# Arguments
- `message::String`: The authentication message containing name and email

# Returns
- `String`: Authentication result message
"""
function wrapped_authenticate(message::String)::String
    # Get session context from the session
    session = current_session()
    store_context = session.context[:context]::ShoeStoreContext
    session_context = ShoeStoreSessionContext(context=store_context)

    # Create params and call authenticate
    params = AuthenticateParams(msg=message, context=session_context)
    authenticate(params)
end

"""
    wrapped_show_inventory(message::String)::String

Tool function to show available inventory.

# Arguments
- `message::String`: The message (optional, not used for this tool)

# Returns
- `String`: Formatted inventory list
"""
function wrapped_show_inventory(message::String)::String
    # Get session context from the session
    session = current_session()
    store_context = session.context[:context]::ShoeStoreContext
    session_context = ShoeStoreSessionContext(context=store_context)

    # Create params and call show_inventory (message is ignored as it's not needed)
    params = ShowInventoryParams(context=session_context)
    show_inventory(params)
end

"""
    wrapped_check_size(message::String)::String

Tool function to check shoe size availability.

# Arguments
- `message::String`: The message containing size and shoe details

# Returns
- `String`: Size availability message
"""
function wrapped_check_size(message::String)::String
    # Get session context from the session
    session = current_session()
    store_context = session.context[:context]::ShoeStoreContext
    session_context = ShoeStoreSessionContext(context=store_context)

    # Create params and call check_size
    params = CheckSizeParams(msg=message, context=session_context)
    check_size(params)
end

# Example usage:
function run_example(custom_messages=nothing)
    # Initialize the context
    context = ShoeStoreContext()

    # Create tools and agent
    agent = Agent(;
        name = "Shoe Store Bot",
        model = "gpt-3.5-turbo",  # Use OpenAI GPT-3.5
        instructions = """
        You are a shoe store customer service bot. You can help with:
        - Authentication: Users must authenticate first
        - Showing available shoes
        - Checking size availability
        Use the available tools to assist customers.
        Always ask for authentication first if the user is not authenticated.
        """
    )

    # Add tools to the agent with explicit type information
    add_tools!(agent, [
        Tool(wrapped_authenticate; name="authenticate", docs="Authenticate user with name and email",
             strict=true),
        Tool(wrapped_show_inventory; name="show_inventory", docs="Show available shoe inventory",
             strict=true),
        Tool(wrapped_check_size; name="check_size", docs="Check availability of specific shoe size",
             strict=true)
    ])

    # Create session with agent and context
    session = Session(agent; context=Dict{Symbol,Any}(:context => context))
    set_current_session!(session)

    # Example conversation
    println("Bot: Welcome to our shoe store! Please authenticate to access our services.")

    # Use custom messages if provided, otherwise use default messages
    messages = custom_messages !== nothing ? custom_messages : [
        "show shoes",  # Should prompt for authentication
        "authenticate: jan svilupp, jan@svilupp.github.com",  # Valid authentication
        "show shoes",  # Should show inventory
        "check size 9 Running Shoes"  # Should check size availability
    ]

    for msg in messages
        println("\nUser: $msg")
        run_full_turn!(session, msg)
    end

    return true
end

# Run the example if this file is run directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_example()
end
