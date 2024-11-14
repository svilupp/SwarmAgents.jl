using SwarmAgents
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
function change_flight!(context::Dict{Symbol,Any}, new_flight::String)
    if !flight_exists(new_flight)
        return "Flight $new_flight does not exist"
    end
    context[:current_flight] = new_flight
    "Flight changed successfully to $new_flight\n$(get_flight_details(new_flight))"
end

# Define our tools
function check_flight_status(context::Dict{Symbol,Any})
    current_flight = get(context, :current_flight, nothing)
    if isnothing(current_flight)
        return "No flight currently booked"
    end
    get_flight_details(current_flight)
end

function change_flight(msg::String, context::Dict{Symbol,Any})
    flight_match = match(r"(?i)change.*flight.*to\s+([A-Z0-9]+)", msg)
    if isnothing(flight_match)
        return "Please specify the new flight number (e.g., 'change flight to FL124')"
    end
    new_flight = flight_match[1]
    change_flight!(context, new_flight)
end

# Example usage:
function run_example()
    # Initialize the context
    context = Dict{Symbol,Any}(
        :current_flight => "FL123",  # User's current flight
        :name => "John Doe",         # User's name
        :booking_ref => "ABC123"     # Booking reference
    )

    # Create tools
    check_status_tool = PT.Tool(
        check_flight_status;
        name = "check_flight_status",
        description = "Check the status of the current flight",
        triggers = ["status", "my flight"]
    )

    change_flight_tool = PT.Tool(
        change_flight;
        name = "change_flight",
        description = "Change the current flight to a new flight",
        triggers = ["change", "switch"]
    )

    # Initialize the agent with tools
    agent = Agent(;
        name = "Airline Bot",
        instructions = """
        You are an airline customer service bot. You can help with:
        - Checking flight status
        - Changing flights
        Use the available tools to assist customers.
        """,
        tools = [check_status_tool, change_flight_tool]
    )

    # Create a session
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
        response = process_message(session, msg)
        println("Bot: $response")
    end
end

# Run the example if this file is run directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_example()
end
