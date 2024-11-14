using SwarmAgents
using SwarmAgents: Tool
using PromptingTools
const PT = PromptingTools
using Dates

"""
Example of a simple airline customer service bot using SwarmAgents.jl
This bot demonstrates:
1. Basic context management (flight information)
2. Flight change functionality
3. Simple conversation flow with error handling
"""

# Define our flight database (in a real application, this would be in a database)
const FLIGHTS = Dict(
    "FL123" => Dict("from" => "New York", "to" => "London", "time" => DateTime(2024, 12, 1, 10, 30)),
    "FL124" => Dict("from" => "London", "to" => "New York", "time" => DateTime(2024, 12, 2, 14, 45)),
    "FL125" => Dict("from" => "Paris", "to" => "New York", "time" => DateTime(2024, 12, 3, 9, 15))
)

"""
Context structure for the airline bot
"""
Base.@kwdef mutable struct AirlineContext
    current_flight::Union{String, Nothing} = nothing
    name::String = ""
    booking_ref::String = ""
end

"""
Check if a flight exists in our database
"""
function flight_exists(flight_number::String)
    haskey(FLIGHTS, flight_number)
end

"""
Get flight details as a formatted string
"""
function get_flight_details(flight_number::String)
    if !flight_exists(flight_number)
        return "Flight not found"
    end
    flight = FLIGHTS[flight_number]
    "Flight $flight_number: $(flight["from"]) to $(flight["to"]) at $(flight["time"])"
end

"""
Change flight in the context
"""
function change_flight!(context::AirlineContext, new_flight::String)
    if !flight_exists(new_flight)
        return "Flight $new_flight does not exist"
    end
    context.current_flight = new_flight
    "Flight changed successfully to $new_flight\n$(get_flight_details(new_flight))"
end

"""
    wrapped_check_status(msg::String, session::Session)::String

Tool function to check the status of the current flight.

# Arguments
- `msg::String`: The user message (unused in this case)
- `session::Session`: The current session containing context

# Returns
- `String`: A message containing the flight details or status
"""
function wrapped_check_status(msg::String, session::Session)::String
    context = session.context::AirlineContext
    if isnothing(context.current_flight)
        return "No flight currently booked"
    end
    get_flight_details(context.current_flight)
end

"""
    wrapped_change_flight(msg::String, session::Session)::String

Tool function to change the current flight based on the message.

# Arguments
- `msg::String`: The user message containing the new flight number
- `session::Session`: The current session containing context

# Returns
- `String`: A confirmation message or error message
"""
function wrapped_change_flight(msg::String, session::Session)::String
    flight_match = match(r"(?i)change.*flight.*to\s+([A-Z0-9]+)", msg)
    if isnothing(flight_match)
        return "Please specify the new flight number (e.g., 'change flight to FL124')"
    end
    new_flight = flight_match[1]
    context = session.context::AirlineContext
    change_flight!(context, new_flight)
end

# Example usage:
function run_example()
    # Initialize the context
    context = AirlineContext(
        current_flight = "FL123",  # User's current flight
        name = "John Doe",         # User's name
        booking_ref = "ABC123"     # Booking reference
    )

    # Create tools and agent
    agent = Agent(;
        name = "Airline Bot",
        instructions = """
        You are an airline customer service bot. You can help with:
        - Checking flight status
        - Changing flights
        Use the available tools to assist customers.
        """
    )

    # Add tools to the agent
    add_tools!(agent, [
        Tool(
            name="check_status",
            parameters=Dict(),
            description="Check the status of your current flight",
            strict=false,
            callable=wrapped_check_status
        ),
        Tool(
            name="change_flight",
            parameters=Dict(),
            description="Change your flight to a new flight number",
            strict=false,
            callable=wrapped_change_flight
        )
    ])

    # Create a session with proper context
    session = Session(agent; context=context)

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
        run_full_turn!(session, msg)
        # The response is already printed by run_full_turn!
    end
end

# Run the example if this file is run directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_example()
end
