using SwarmAgents
using PromptingTools
using Dates

# Verify OpenAI API key is available
if !haskey(ENV, "OPENAI_API_KEY")
    error("OpenAI API key not found in environment variables")
end

# Include agent definitions
include("auth_agent.jl")
include("inventory_agent.jl")
include("sizing_agent.jl")

"""
Example of a shoe store customer service bot with multiple specialized agents.
This bot demonstrates:
1. Authentication flow with name/email validation
2. Multi-agent system with specialized roles
3. Proper agent handoffs
4. Session state persistence
5. Context handling
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
    name::Union{String,Nothing} = nothing
    email::Union{String,Nothing} = nothing
    cart::Vector{String} = String[]
end

# Helper functions
"""
Validate authentication credentials
"""
function validate_credentials(name::String, email::String)
    lowercase_name = lowercase(name)
    haskey(VALID_USERS, lowercase_name) && VALID_USERS[lowercase_name] == email
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
    auth_match = match(r"(?i)authenticate:\s*([^,]+),\s*([^\s]+@[^\s]+)", msg)
    isnothing(auth_match) ? (nothing, nothing) : (strip(auth_match[1]), strip(auth_match[2]))
end

# Session management
const CURRENT_SESSION = Ref{Union{Nothing,Session}}(nothing)

function current_session()::Session
    isnothing(CURRENT_SESSION[]) && error("No active session. Please initialize a session first.")
    CURRENT_SESSION[]
end

function set_current_session!(session::Session)
    CURRENT_SESSION[] = session
end

# Example usage
function run_example(custom_messages=nothing)
    # Initialize the context
    context = ShoeStoreContext()

    # Create initial authentication agent
    agent = create_auth_agent()

    # Create session with agent and context
    session = Session(agent; context=Dict{Symbol,Any}(:context => context))
    set_current_session!(session)

    # Welcome message
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
        # Run the interaction and check for agent transfers
        result = run_full_turn!(session, msg)

        # Check if we need to transfer to a different agent
        if result isa Agent
            session = Session(result; context=session.context)
            set_current_session!(session)
            # Run the original message with the new agent
            run_full_turn!(session, msg)
        end
    end

    return true
end

# Run the example if this file is run directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_example()
end
