using SwarmAgents
using PromptingTools
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

# Initialize the flight database and global context
const FLIGHT_DB = FlightDatabase()
const GLOBAL_CONTEXT = Dict{Symbol,Any}(
    :current_flight => "FL123",
    :name => "John Doe",
    :booking_ref => "ABC123"
)

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

"""
Check the status of the current flight.
"""
function check_flight_status(message::String)::String
    get_flight_details(GLOBAL_CONTEXT[:current_flight])
end

"""
Change the current flight to a new flight number.
"""
function change_flight(message::String)::String
    m = match(r"FL\d+", message)
    if isnothing(m)
        return "No valid flight number found in request. Please specify a flight number (e.g., FL124)"
    end
    new_flight = m.match

    if !flight_exists(new_flight)
        return "Flight $new_flight does not exist"
    end

    # Update global context
    GLOBAL_CONTEXT[:current_flight] = new_flight
    return "Flight changed successfully to $new_flight\n$(get_flight_details(new_flight))"
end

# Example usage:
function run_example()
    # Set up OpenAI API key for PromptingTools
    if !haskey(ENV, "OPENAI_API_KEY")
        ENV["OPENAI_API_KEY"] = "$OPENAI_API_KEY"  # Use the secret provided
    end

    # Create tool map using PromptingTools tool_call_signature
    tool_map = PT.tool_call_signature([check_flight_status, change_flight])

    # Example conversation
    println("Bot: Welcome to our airline service! How can I help you today?\n")

    # Process messages
    messages = [
        "What's my flight status?",
        "Change flight to FL124",
        "What's my flight status?"
    ]

    conv = """
    You are an airline customer service bot. You can help with:
    - Checking flight status
    - Changing flights
    Use the available tools to assist customers.
    Always refer to the customer by their name (available in context).

    How can I help you today?
    """

    for (i, msg) in enumerate(messages)
        println("\nUser: $msg")
        num_iter = 0
        while num_iter <= 5
            conv = aitools(conv * "\nUser: " * msg;
                tools=collect(values(tool_map)),
                return_all=true,
                verbose=true,
                model="gpt-3.5-turbo")

            # Print assistant response
            !isnothing(PT.last_output(conv)) && println("Bot: $(PT.last_output(conv))")

            # Terminate if no further tool calls
            isempty(conv[end].tool_calls) && break

            # Process tool calls
            for tool in conv[end].tool_calls
                name, args = tool.name, tool.args
                @info "Tool Request: $name, args: $args"
                tool.content = PT.execute_tool(tool_map[name], args)
                @info "Tool Output: $(tool.content)"
                push!(conv, tool)
            end
            num_iter += 1
        end
    end

    return true
end

# Run the example if this file is run directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_example()
end
