using SwarmAgents
using PromptingTools
const PT = PromptingTools
using PromptingTools: aitools
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

# Define tool argument structures that match PromptingTools' expected schema
Base.@kwdef struct WrapperMessageArgs
    message::String
end

Base.@kwdef struct WrapperArgs
    args::WrapperMessageArgs
end

Base.@kwdef struct ToolMessageArgs
    message::String
end

Base.@kwdef struct ToolInnerArgs
    args::ToolMessageArgs
end

Base.@kwdef struct ToolArgs
    args::ToolInnerArgs
end

# Convert JSON3/Dict to WrapperArgs
function dict_to_wrapper_args(args::Union{Dict{Symbol,Any},Dict{String,Any},JSON3.Object})::WrapperArgs
    try
        # Handle both simple and nested structures from PromptingTools
        message = if args isa Dict{Symbol,Any}
            args_obj = args[:args]
            if args_obj isa String
                # Simple case: :args contains the message directly
                args_obj
            elseif args_obj isa Dict && haskey(args_obj, "message")
                # Nested case: :args contains a Dict with "message" key
                args_obj["message"]
            else
                error("Unable to find message in Symbol-keyed arguments: $args_obj")
            end
        else
            # For String keys or JSON3.Object
            if haskey(args, "args")
                args_obj = args["args"]
                if args_obj isa String
                    # Simple case: "args" contains the message directly
                    args_obj
                elseif haskey(args_obj, "message")
                    # Nested case: "args" contains a Dict with "message" key
                    args_obj["message"]
                else
                    error("Unable to find message in String-keyed arguments: $args_obj")
                end
            else
                error("Unable to find 'args' key in arguments: $args")
            end
        end

        return WrapperArgs(args=WrapperMessageArgs(message=message))
    catch e
        @error "Failed to parse wrapper args" args typeof(args) exception=(e, catch_backtrace())
        rethrow(e)
    end
end

# Convert JSON3/Dict to ToolArgs
function json_to_tool_args(args::Union{Dict{Symbol,Any},Dict{String,Any},JSON3.Object})::ToolArgs
    try
        # Handle nested structure from PromptingTools
        message = if args isa Dict{Symbol,Any}
            # args[:args] is already a JSON3.Object, access it directly
            args_obj = args[:args]
            if haskey(args_obj, "args") && haskey(args_obj["args"], "args") &&
               haskey(args_obj["args"]["args"], "message")
                args_obj["args"]["args"]["message"]
            else
                error("Unable to find message in Symbol-keyed arguments: $args_obj")
            end
        else
            # For String keys or JSON3.Object, assume already parsed
            if haskey(args, "args") && haskey(args["args"], "args") &&
               haskey(args["args"]["args"], "message")
                args["args"]["args"]["message"]
            else
                error("Unable to find message in String-keyed arguments: $args")
            end
        end

        return ToolArgs(
            args=ToolInnerArgs(
                args=ToolMessageArgs(
                    message=message
                )
            )
        )
    catch e
        @error "Failed to parse tool args" args typeof(args) exception=(e, catch_backtrace())
        rethrow(e)
    end
end

# Convert ToolArgs back to Dict{Symbol} for PromptingTools compatibility
function tool_args_to_dict(args::ToolArgs)::Dict{Symbol,Any}
    Dict{Symbol,Any}(
        :args => Dict{String,Any}(
            "args" => Dict{String,Any}(
                "args" => Dict{String,Any}(
                    "message" => args.args.args.message
                )
            )
        )
    )
end

# Convert WrapperArgs back to Dict{Symbol} for PromptingTools compatibility
function wrapper_args_to_dict(args::WrapperArgs)::Dict{Symbol,Any}
    Dict{Symbol,Any}(
        :args => Dict{String,Any}(
            "args" => Dict{String,Any}(
                "message" => args.args.message
            )
        )
    )
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
function check_flight_status(args::ToolArgs)::String
    # Use the message from the structured arguments directly
    get_flight_details(GLOBAL_CONTEXT[:current_flight])
end

"""
Change the current flight to a new flight number.
"""
function change_flight(args::ToolArgs)::String
    # Extract flight number from message
    m = match(r"FL\d+", args.args.args.message)
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

# Create wrapper functions that handle both Dict and struct-based arguments
"""
Check the status of a flight using a wrapper that handles both Dict and struct-based arguments.
"""
function wrapped_check_status(args::Union{Dict,WrapperArgs})::String
    @info "Wrapped check status received args:" args
    # Convert Dict to WrapperArgs if needed
    wrapper_args = args isa Dict ? dict_to_wrapper_args(args) : args
    check_flight_status(ToolArgs(
        args=ToolInnerArgs(
            args=ToolMessageArgs(
                message=wrapper_args.args.message
            )
        )
    ))
end

"""
Change flight using a wrapper that handles both Dict and struct-based arguments.
"""
function wrapped_change_flight(args::Union{Dict,WrapperArgs})::String
    @info "Wrapped change flight received args:" args
    # Convert Dict to WrapperArgs if needed
    wrapper_args = args isa Dict ? dict_to_wrapper_args(args) : args
    change_flight(ToolArgs(
        args=ToolInnerArgs(
            args=ToolMessageArgs(
                message=wrapper_args.args.message
            )
        )
    ))
end

# Example usage:
function run_example()
    # Set up OpenAI API key for PromptingTools
    if !haskey(ENV, "OPENAI_API_KEY")
        ENV["OPENAI_API_KEY"] = "$OPENAI_API_KEY"  # Use the secret provided
    end

    # Create tool map using the wrapped functions
    tool_map = PT.tool_call_signature([wrapped_check_status, wrapped_change_flight])
    tools = collect(values(tool_map))

    # Example conversation
    println("Bot: Welcome to our airline service! How can I help you today?\n")

    # Process messages
    messages = [
        "What's my flight status?",
        "Change flight to FL124",
        "What's my flight status?"
    ]

    # Initialize conversation with system message
    conv = Vector{PT.AbstractChatMessage}([PT.SystemMessage("""
    You are an airline customer service bot. You can help with:
    - Checking flight status
    - Changing flights
    Use the available tools to assist customers.
    Always refer to the customer by their name (available in context).

    How can I help you today?
    """)])

    for (i, msg) in enumerate(messages)
        println("\nUser: $msg")
        num_iter = 0
        while num_iter <= 5
            # Add user message to conversation
            push!(conv, PT.UserMessage(msg))

            # Get AI response
            conv = aitools(conv;
                tools=tools,
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
                try
                    # Convert Dict to WrapperArgs, then back to Dict for PromptingTools
                    wrapper_args = dict_to_wrapper_args(args)
                    tool_dict_args = wrapper_args_to_dict(wrapper_args)
                    tool.content = PT.execute_tool(tool_map[name], tool_dict_args)
                    @info "Tool Output: $(tool.content)"
                catch e
                    @error "Tool execution failed" exception=(e, catch_backtrace())
                    tool.content = "Sorry, I encountered an error. Please try again."
                end
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
