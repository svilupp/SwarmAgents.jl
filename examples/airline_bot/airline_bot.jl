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

# Define flight information structure
Base.@kwdef struct Flight
    from::String
    to::String
    time::DateTime
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

# Context structure
Base.@kwdef mutable struct AirlineContext
    current_flight::String = "FL123"
    name::String = "John Doe"
    booking_ref::String = "ABC123"
end

# Convert AirlineContext to Dict for SwarmAgents.Session
function to_dict(ctx::AirlineContext)::Dict{Symbol, Any}
    Dict{Symbol, Any}(
        :current_flight => ctx.current_flight,
        :name => ctx.name,
        :booking_ref => ctx.booking_ref
    )
end

# Create AirlineContext from Dict
function from_dict(dict::Dict{Symbol, Any})::AirlineContext
    AirlineContext(
        current_flight = get(dict, :current_flight, "FL123"),
        name = get(dict, :name, "John Doe"),
        booking_ref = get(dict, :booking_ref, "ABC123")
    )
end

"""
Check if a flight exists in our database
"""
function flight_exists(flight_number::String)
    any(f -> f[1] == flight_number, FLIGHT_DB.flights)
end

"""
Get flight details as a formatted string
"""
function get_flight_details(flight_number::String)
    if !flight_exists(flight_number)
        return "Flight not found"
    end
    flight = first(f[2] for f in FLIGHT_DB.flights if f[1] == flight_number)
    "Flight $flight_number: $(flight.from) to $(flight.to) at $(flight.time)"
end

# SwarmAgents integration wrapper functions
"""
Check the status of the current flight.

Returns detailed information about the flight, including departure city, destination, and time.

Parameters:
    content::String - The message content (unused in this function)
    context::Dict{Symbol, Any} - The session context containing flight information

Returns:
    String - A formatted string containing flight details or an error message
"""
function check_status_tool(content::String, context::Dict{Symbol, Any})::String
    ctx = from_dict(context)
    get_flight_details(ctx.current_flight)
end

"""
Change the current flight to a new flight number.

Extracts a flight number from the message content and updates the context.

Parameters:
    content::String - The message content containing the new flight number
    context::Dict{Symbol, Any} - The session context to update

Returns:
    String - A success message with new flight details or an error message
"""
function change_flight_tool(content::String, context::Dict{Symbol, Any})::String
    m = match(r"FL\d+", content)
    if isnothing(m)
        return "No valid flight number found in request. Please specify a flight number (e.g., FL124)"
    end
    new_flight = m.match

    if !flight_exists(new_flight)
        return "Flight $new_flight does not exist"
    end

    ctx = from_dict(context)
    ctx.current_flight = new_flight
    context[:current_flight] = new_flight

    return "Flight changed successfully to $new_flight\n$(get_flight_details(new_flight))"
end

# Example usage:
function run_example()
    # Set up OpenAI API key for PromptingTools
    if !haskey(ENV, "OPENAI_API_KEY")
        ENV["OPENAI_API_KEY"] = "$OPENAI_API_KEY"  # Use the secret provided
    end

    # Initialize the context as a struct
    context = AirlineContext(
        current_flight = "FL123",  # User's current flight
        name = "John Doe",         # User's name
        booking_ref = "ABC123"     # Booking reference
    )

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
        PT.Tool(check_status_tool),
        PT.Tool(change_flight_tool)
    ])

    # Create a session with proper context
    session = Session(agent; context=to_dict(context))

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

    return true
end

# Run the example if this file is run directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_example()
end
