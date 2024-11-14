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

# Define our conversation flow rules
struct AirlineFlowRules <: AbstractFlowRules end

"""
Initialize the context with user's flight information
"""
function initialize_context()
    Dict(
        "current_flight" => "FL123",  # User's current flight
        "name" => "John Doe",         # User's name
        "booking_ref" => "ABC123"     # Booking reference
    )
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
function change_flight!(context::Dict, new_flight::String)
    if !flight_exists(new_flight)
        return false, "Flight $new_flight does not exist"
    end
    context["current_flight"] = new_flight
    return true, "Flight changed successfully to $new_flight"
end

"""
Process user message and update context accordingly
"""
function SwarmAgents.process_message(rules::AirlineFlowRules, message::String, context::Dict)
    # Convert message to lowercase for easier matching
    msg = lowercase(message)

    # Check flight status
    if contains(msg, "status") || contains(msg, "my flight")
        current_flight = context["current_flight"]
        return get_flight_details(current_flight)

    # Change flight
    elseif contains(msg, "change") && contains(msg, "flight")
        # Extract flight number (assuming format "change flight to FL124")
        flight_match = match(r"(?i)change.*flight.*to\s+([A-Z0-9]+)", message)
        if isnothing(flight_match)
            return "Please specify the new flight number (e.g., 'change flight to FL124')"
        end

        new_flight = flight_match[1]
        success, message = change_flight!(context, new_flight)
        if success
            return "$(message)\n$(get_flight_details(new_flight))"
        else
            return message
        end

    # Help message
    elseif contains(msg, "help")
        return """
        I can help you with:
        - Checking flight status: "What's my flight status?"
        - Changing flights: "Change flight to FL124"
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
        AirlineFlowRules(),
        initialize_context()
    )

    # Example conversation
    println("Bot: Welcome to our airline service! How can I help you today?")
    println("\nUser: What's my flight status?")
    println("Bot: ", process_message(bot.rules, "What's my flight status?", bot.context))

    println("\nUser: Change flight to FL124")
    println("Bot: ", process_message(bot.rules, "Change flight to FL124", bot.context))

    println("\nUser: What's my flight status?")
    println("Bot: ", process_message(bot.rules, "What's my flight status?", bot.context))
end

# Run the example if this file is run directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_example()
end
