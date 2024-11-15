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

# Context and parameter structures
Base.@kwdef mutable struct AirlineContext
    current_flight::String = "FL123"
    name::String = "John Doe"
    booking_ref::String = "ABC123"
end

# Parameter structures for tools
Base.@kwdef struct CheckStatusParams
    none::Nothing = nothing
end

Base.@kwdef struct ChangeFlightParams
    new_flight::String = ""  # Will be populated from message content
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

# Core tool functions
function check_status(flight_number::String)::String
    get_flight_details(flight_number)
end

function change_flight(current_flight::String, new_flight::String)::String
    if !flight_exists(new_flight)
        return "Flight $new_flight does not exist"
    end
    "Flight changed successfully to $new_flight\n$(get_flight_details(new_flight))"
end

# Tool wrapper functions for Tool constructor
"""
Check the status of a flight
Input: AIToolRequest and Session
Output: flight details as string
"""
function check_status_tool(msg::PT.AIToolRequest, session::Session)::String
    current_flight = session.context[:current_flight]::String
    get_flight_details(current_flight)
end

"""
Change flight to a new flight number
Input: AIToolRequest and Session
Output: success/failure message as string
"""
function change_flight_tool(msg::PT.AIToolRequest, session::Session)::String
    # Extract flight number from message content
    m = match(r"FL\d+", msg.content)
    if isnothing(m)
        return "No valid flight number found in request. Please specify a flight number (e.g., FL124)"
    end
    new_flight = m.match

    # Check if flight exists and update context
    if !flight_exists(new_flight)
        return "Flight $new_flight does not exist"
    end

    # Update context and return success message
    session.context[:current_flight] = new_flight
    "Flight changed successfully to $new_flight\n$(get_flight_details(new_flight))"
end

# Example usage:
function run_example()
    # Set up OpenAI API key for PromptingTools
    if !haskey(ENV, "OPENAI_API_KEY")
        error("OPENAI_API_KEY environment variable not set. Please set it before running the example.")
    end
    PT.OPENAI_API_KEY = ENV["OPENAI_API_KEY"]

    # Initialize the context as a Dict
    context = Dict{Symbol,Any}(
        :current_flight => "FL123",  # User's current flight
        :name => "John Doe",         # User's name
        :booking_ref => "ABC123"     # Booking reference
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
        """
    )

    # Add tools to the agent
    add_tools!(agent, [
        Tool(check_status_tool),
        Tool(change_flight_tool)
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

    return true
end

# Run the example if this file is run directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_example()
end
