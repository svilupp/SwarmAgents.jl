using SwarmAgents
using PromptingTools

# Initialize OpenAI API key
!haskey(ENV, "OPENAI_API_KEY") && (ENV["OPENAI_API_KEY"] = "$OPENAI_API_KEY")

"""
    check_flight_status(flight_inquiry::String, context::Dict)::String

Show current flight details and status for the customer's active booking.
Returns formatted string with flight details including route, time, and status.
Reflects intent: Providing clear, up-to-date flight information to assist customer decision-making.
"""
function check_flight_status(flight_inquiry::String, context::Dict)::String
    flight = context[:flights][context[:current_flight]]
    "📋 Checking flight status... \nFlight $(context[:current_flight]): $(flight["from"]) to $(flight["to"]) at $(flight["time"]) - Status: $(flight["status"])\nWould you like to make any changes to your booking?"
end

"""
    change_flight(desired_flight_number::String, context::Dict)::String

Update customer's booking to a new flight number, with automatic context updates.
Returns confirmation message with new flight details or available alternatives if flight not found.
Reflects intent: Assisting customer with flight changes while maintaining booking consistency.
"""
function change_flight(desired_flight_number::String, context::Dict)::String
    # Reflect intent: Attempting to change customer's flight
    if !haskey(context[:flights], desired_flight_number)
        return """
        🔍 Checking available flights...
        Sorry, flight $desired_flight_number is not available.
        Available options: $(join(keys(context[:flights]), ", "))
        Please choose from these flight numbers.
        """
    end

    old_flight = context[:current_flight]
    context[:current_flight] = desired_flight_number
    flight = context[:flights][desired_flight_number]

    """
    ✈️ Processing flight change...
    ✅ Successfully changed from $old_flight to $desired_flight_number
    New Flight Details:
    From: $(flight["from"])
    To: $(flight["to"])
    Time: $(flight["time"])

    Need help with anything else?
    """
end

"""
    transfer_to_booking(booking_request::String, context::Dict)::AgentRef

Switch to booking specialist for complex booking changes and special requests.
Returns AgentRef to the booking specialist agent for seamless handover.
Reflects intent: Ensuring complex booking requests are handled by specialized agent.
"""
function transfer_to_booking(booking_request::String, context::Dict)::AgentRef
    # Reflect intent: Transferring to specialist for complex booking
    println("""
    👋 I'll transfer you to our booking specialist who can better assist with complex changes.
    Your request: "$booking_request"
    All your flight information will be preserved.
    """)

    AgentRef(:booking_specialist)
end

# Initialize agents
airline_service = Agent(
    name = "Airline Service",
    model = "gpt4o",
    instructions = """
    You are an airline service assistant that helps customers with flight information and simple changes.

    CAPABILITIES:
    ✓ Check flight status using customer's current flight from context
    ✓ Change flight bookings with automatic context updates
    ✓ Transfer complex requests to booking specialist

    ROUTINES:
    1. For status checks:
       - Use check_flight_status to view current booking
       - Offer to help with changes if needed

    2. For flight changes:
       - Use change_flight with the new flight number
       - Verify flight exists before changing
       - Confirm successful changes

    3. For complex requests:
       - Use transfer_to_booking for:
         * Multiple booking changes
         * Special assistance
         * Complex itineraries

    LIMITATIONS:
    × Cannot process payments
    × Cannot create new flights
    × Cannot modify flight schedules

    Remember: All customer flight information is preserved in context during transfers.
    """
)

booking_specialist = Agent(
    name = "Booking Specialist",
    model = "gpt4o",
    instructions = """
    You are a booking specialist handling complex flight changes.

    CAPABILITIES:
    ✓ Handle multiple bookings in one session
    ✓ Provide detailed booking assistance
    ✓ Access full flight context from previous agent

    ROUTINES:
    1. For multiple bookings:
       - Review current flight from context
       - Suggest connected flights
       - Update context with changes

    2. For special requests:
       - Check available options
       - Provide detailed recommendations
       - Maintain booking history

    LIMITATIONS:
    × Cannot process payments
    × Cannot create new flights
    """
)

# Create agent map
agent_map = Dict(
    :airline_service => airline_service,
    :booking_specialist => booking_specialist
)

# Add tools to airline service agent
add_tools!(airline_service, [check_flight_status, change_flight, transfer_to_booking]; hidden_fields=["context"])

# Initialize session with agent map
session = Session(
    airline_service,
    agent_map = agent_map,
    context = Dict(
        :current_flight => "FL123",
        :flights => Dict(
            "FL123" => Dict("from" => "New York", "to" => "London", "time" => "2024-12-01 10:30", "status" => "On Time"),
            "FL124" => Dict("from" => "London", "to" => "New York", "time" => "2024-12-02 14:45", "status" => "On Time"),
            "FL125" => Dict("from" => "Paris", "to" => "New York", "time" => "2024-12-03 09:15", "status" => "Delayed")
        )
    )
)

# Example usage
if abspath(PROGRAM_FILE) == @__FILE__
    println("\n=== SwarmAgents.jl Airline Bot Demo ===")
    println("Demonstrating seamless multi-agent conversations with automatic context handling\n")

    # Example conversation showing natural progression from simple queries to complex booking
    messages = [
        # Simple flight status check - demonstrates basic tool usage
        "Hi! Can you tell me about my flight to London?",

        # Flight change request - shows automatic context updates
        "Thanks! Actually, I see there's a return flight FL124. Can I switch to that one?",

        # Complex booking request - demonstrates seamless agent transfer
        "Perfect! Now I'd like to add some stops in Paris and Rome on my way back"
    ]

    for msg in messages
        println("\nUser: $msg")

        # Each run_full_turn! automatically handles:
        # - Tool selection and execution
        # - Context management
        # - Agent transfers when needed
        result = run_full_turn!(session, msg)

        # Seamlessly transfer to specialist agent when needed
        if result isa AgentRef || result isa Agent
            session = Session(session.agent_map[result isa AgentRef ? result.name : :booking_specialist];
                            agent_map=session.agent_map,
                            context=session.context)
        end
    end
end
