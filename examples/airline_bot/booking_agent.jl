using SwarmAgents
using PromptingTools
using Dates

"""
    change_flight(message::String)::String

Change the customer's flight to a new flight number.
Returns success/failure message and flight details.

Usage:
    change_flight("FL124")

Intent: Process flight change request and update customer's booking.
"""
function change_flight(message::String)::String
    flight_number = strip(message)

    if !flight_exists(flight_number)
        return """
        Sorry, flight $flight_number does not exist.
        Available flights:
        $(join([f[1] for f in FLIGHT_DB.flights], ", "))
        """
    end

    # Update context
    context = current_session().context[:context]
    context.current_flight = flight_number

    return """
    Flight changed successfully to $flight_number
    $(get_flight_details(flight_number))
    Would you like to check the status of your new flight?
    """
end

"""
    transfer_to_status(message::String)::Tuple{Agent,String}

Transfer customer to status agent for flight status checks.
Returns status agent instance and handover message.

Usage:
    transfer_to_status("check status")

Intent: Ensure smooth transition to status checking functionality.
"""
function transfer_to_status(message::String)::Tuple{Agent,String}
    context = current_session().context[:context]

    handover_message = """
    Transferring you to our Status Agent.
    Customer Details:
    - Name: $(context.name)
    - Booking: $(context.booking_ref)
    - Current Flight: $(context.current_flight)

    They'll help you check your flight status!
    """

    status_agent = create_status_agent()
    status_agent.context = current_session().context

    return (status_agent, handover_message)
end

"""
Create the booking agent with specific tools and instructions.
"""
function create_booking_agent()::Agent
    agent = Agent(;
        name = "Booking Agent",
        model = "gpt4o",
        instructions = """
        You are an airline booking agent specializing in flight changes.

        What you can do:
        - Change customer's flight to a different flight number
        - Transfer to status agent for flight status checks
        - Access customer's booking information

        What you cannot do:
        - Check flight status directly (transfer to status agent)
        - Create new flights
        - Modify flight database

        Routine:
        1. When customer wants to change flights, verify flight exists
        2. Update booking with new flight number
        3. Provide confirmation with new flight details
        4. If status check needed, transfer to status agent
        5. Always be professional and courteous

        Example queries:
        - "change to flight FL124"
        - "book me on FL125"
        - "check my flight status" (will transfer to status agent)
        """
    )

    # Add tools with clear names and docstrings
    add_tools!(agent, [
        change_flight,
        transfer_to_status
    ]; hidden_fields=["context"])

    return agent
end
