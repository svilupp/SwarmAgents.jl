using SwarmAgents
using PromptingTools
using Dates

"""
    check_flight_status(message::String)::String

Check the status of the customer's current flight.
Returns detailed flight information including route and time.

Usage:
    check_flight_status("status")

Intent: Provide customer with current flight status and details.
"""
function check_flight_status(message::String)::String
    context = current_session().context[:context]
    flight_details = get_flight_details(context.current_flight)

    return """
    Hello $(context.name), here's your flight status:
    $flight_details

    Would you like to:
    1. Change to a different flight
    2. Check another flight status
    """
end

"""
    transfer_to_booking(message::String)::Tuple{Agent,String}

Transfer customer to booking agent for flight changes.
Returns booking agent instance and handover message.

Usage:
    transfer_to_booking("change flight")

Intent: Ensure smooth transition to flight booking functionality.
"""
function transfer_to_booking(message::String)::Tuple{Agent,String}
    context = current_session().context[:context]

    handover_message = """
    Transferring you to our Booking Agent.
    Customer Details:
    - Name: $(context.name)
    - Booking: $(context.booking_ref)
    - Current Flight: $(context.current_flight)

    They'll help you change your flight!
    """

    booking_agent = create_booking_agent()
    booking_agent.context = current_session().context

    return (booking_agent, handover_message)
end

"""
Create the status agent with specific tools and instructions.
"""
function create_status_agent()::Agent
    agent = Agent(;
        name = "Status Agent",
        model = "gpt4o",
        instructions = """
        You are an airline status agent specializing in flight status checks.

        What you can do:
        - Check status of customer's current flight
        - Provide detailed flight information
        - Transfer to booking agent for flight changes

        What you cannot do:
        - Change flights directly (transfer to booking agent)
        - Create new flights
        - Modify flight database

        Routine:
        1. When asked about flight status, provide complete details
        2. Include route and timing information
        3. Suggest next steps (change flight or check another)
        4. If flight change needed, transfer to booking agent
        5. Always be professional and courteous

        Example queries:
        - "what's my flight status"
        - "tell me about my flight"
        - "I want to change flights" (will transfer to booking agent)
        """
    )

    # Add tools with clear names and docstrings
    add_tools!(agent, [
        check_flight_status,
        transfer_to_booking
    ]; hidden_fields=["context"])

    return agent
end
