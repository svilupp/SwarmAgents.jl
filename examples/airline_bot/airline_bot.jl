using SwarmAgents
using SwarmAgents: Tool, Session, Agent
using PromptingTools
using PromptingTools: AbstractMessage, UserMessage, SystemMessage, AIToolRequest,
                     ToolMessage, TestEchoOpenAISchema
const PT = PromptingTools
using Dates
using JSON3

"""
Example of a simple airline customer service bot using SwarmAgents.jl
This bot demonstrates:
1. Basic context management (flight information)
2. Flight change functionality
3. Simple conversation flow with error handling
"""

# Define tool request structures
Base.@kwdef struct CheckFlightStatus
    message::String
end

Base.@kwdef struct ChangeFlightRequest
    message::String
end

# Define flight information structure
Base.@kwdef struct Flight
    from::String
    to::String
    time::DateTime
end

# Define context structure for the session
Base.@kwdef struct AirlineContext
    current_flight::String = "FL123"
    name::String = "John Doe"
    booking_ref::String = "ABC123"
end

# Define flight database structure
Base.@kwdef struct FlightDatabase
    flights::Vector{Tuple{String, Flight}} = [
        ("FL123", Flight(from="New York", to="London", time=DateTime(2024, 12, 1, 10, 30))),
        ("FL124", Flight(from="London", to="New York", time=DateTime(2024, 12, 2, 14, 45))),
        ("FL125", Flight(from="Paris", to="New York", time=DateTime(2024, 12, 3, 9, 15)))
    ]
end

# Initialize the flight database
const FLIGHT_DB = FlightDatabase()

# Global session reference
mutable struct GlobalSession
    session::Union{Nothing, Session}
end

const GLOBAL_SESSION = GlobalSession(nothing)

"""
Check if a flight exists in our database
"""
function flight_exists(flight_number::String)::Bool
    any(f -> f[1] == flight_number, FLIGHT_DB.flights)
end

"""
Get flight details as a formatted string
"""
function get_flight_details(flight_number::String)::String
    if !flight_exists(flight_number)
        return "Flight not found"
    end
    flight = first(f[2] for f in FLIGHT_DB.flights if f[1] == flight_number)
    "Flight $flight_number: $(flight.from) to $(flight.to) at $(flight.time)"
end

# SwarmAgents integration wrapper functions

"""
    check_status_wrapper(request::CheckFlightStatus)::String

Check the status of the current flight.

# Arguments
- `request::CheckFlightStatus`: The request containing the user's message

# Returns
- `String`: A formatted string containing the flight details
"""
function check_status_wrapper(request::CheckFlightStatus)::String
    check_status_tool(request.message, GLOBAL_SESSION.session)
end

"""
    change_flight_wrapper(request::ChangeFlightRequest)::String

Change the current flight to a new flight number.

# Arguments
- `request::ChangeFlightRequest`: The request containing the user's message with new flight number

# Returns
- `String`: A confirmation message with the new flight details
"""
function change_flight_wrapper(request::ChangeFlightRequest)::String
    change_flight_tool(request.message, GLOBAL_SESSION.session)
end

"""
    check_status_tool(message::String, session::Session)::String

Internal implementation for checking flight status.
"""
function check_status_tool(message::String, session::Session)::String
    context = AirlineContext(;
        current_flight=session.context[:current_flight],
        name=session.context[:name],
        booking_ref=session.context[:booking_ref]
    )
    get_flight_details(context.current_flight)
end

"""
    change_flight_tool(message::String, session::Session)::String

Internal implementation for changing flights.
"""
function change_flight_tool(message::String, session::Session)::String
    m = match(r"FL\d+", message)
    if isnothing(m)
        return "No valid flight number found in request. Please specify a flight number (e.g., FL124)"
    end
    new_flight = m.match

    if !flight_exists(new_flight)
        return "Flight $new_flight does not exist"
    end

    # Update context dictionary
    session.context[:current_flight] = new_flight
    return "Flight changed successfully to $new_flight\n$(get_flight_details(new_flight))"
end

# Example usage:
function run_example()
    # Set up OpenAI API key for PromptingTools
    if !haskey(ENV, "OPENAI_API_KEY")
        ENV["OPENAI_API_KEY"] = "$OPENAI_API_KEY"  # Use the secret provided
    end

    # Create tools and agent
    agent = Agent(;
        name = "Airline Bot",
        model = "gpt-3.5-turbo",  # Use OpenAI GPT-3.5
        instructions = """
        You are an airline customer service bot. You can help with:
        - Checking flight status
        - Changing flights
        Use the available tools to assist customers.
        Always refer to the customer by their name (available in context).
        """
    )

    # Add tools to the agent
    add_tools!(agent, [
        Tool(check_status_wrapper;
            name="check_flight_status",
            docs="Check the status of the current flight"
        ),
        Tool(change_flight_wrapper;
            name="change_flight",
            docs="Change the current flight to a new flight number"
        )
    ])

    # Create a session with proper context and store it globally
    GLOBAL_SESSION.session = Session(agent; context=Dict{Symbol,Any}(:current_flight => "FL123", :name => "John Doe", :booking_ref => "ABC123"))

    # Example conversation
    println("Bot: Welcome to our airline service! How can I help you today?")

    # Process messages through the session
    messages = [
        "What's my flight status?",
        "Change flight to FL124",
        "What's my flight status?"
    ]

    for (i, msg) in enumerate(messages)
        println("\nUser: $msg")
        run_full_turn!(GLOBAL_SESSION.session, msg)
        # The response is already printed by run_full_turn!
    end

    return true
end

# Run the example if this file is run directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_example()
end
