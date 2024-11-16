"""
    print_progress(io::Union{IO, Nothing}, agent::Union{AbstractAgent, Nothing}, msg::AbstractMessage)

Print progress messages for agent actions.
"""
function print_progress(io::Union{IO, Nothing}, agent::Union{AbstractAgent, Nothing}, msg)
    isnothing(io) && return nothing
    agent_name = isnothing(agent) ? "System" : agent.name
    printstyled(io, ">> $agent_name: ", color=:light_blue)
    if PT.isaitoolrequest(msg)
        tool_calls = msg.tool_calls
        if length(tool_calls) > 0
            printstyled(io, "Tool Request: Using tool: $(tool_calls[1].name)\n", color=:light_yellow)
            # Print tool arguments if present in the first tool call
            if hasfield(typeof(tool_calls[1]), :arguments)
                args = tool_calls[1].arguments
                if args isa AbstractDict
                    for (key, value) in args
                        printstyled(io, "$key: $value\n", color=:light_yellow)
                    end
                else
                    printstyled(io, "Arguments: $args\n", color=:light_yellow)
                end
            end
        else
            printstyled(io, "Tool Request: Using tool: unknown\n", color=:light_yellow)
        end
    elseif PT.istoolmessage(msg)
        printstyled(io, "Tool Output: Using tool: $(msg.name)\n", color=:light_yellow)
        if hasfield(typeof(msg), :args) && !isnothing(msg.args)
            args = msg.args
            if args isa AbstractDict
                for (key, value) in args
                    printstyled(io, "$key: $value\n", color=:light_yellow)
                end
            end
        end
        if !isnothing(msg.content)
            printstyled(io, "Tool response: $(msg.content)\n", color=:light_green)
        end
    else
        content = PT.last_output(msg)
        isnothing(content) && return nothing
        printstyled(io, content, "\n", color=:light_blue)
    end
    return nothing
end

"""
    scrub_agent_name(agent::AbstractAgent)

Clean up agent name for display.
"""
function scrub_agent_name(agent::AbstractAgent)
    return replace(agent.name, r"[^a-zA-Z0-9]" => "_")
end

"""
    convert_message(T::Type{<:PT.AbstractMessage}, msg::PT.AbstractMessage)

Convert a message to the specified message type.
"""
function convert_message(T::Type{<:PT.AbstractMessage}, msg::PT.AbstractMessage)
    msg isa T && return msg
    if PT.issystemmessage(msg)
        return T(msg.content, msg.name, msg.role, Dict{Symbol,Any}(), :system)
    elseif PT.isusermessage(msg)
        return T(msg.content, msg.name, msg.role, Dict{Symbol,Any}(), :user)
    elseif PT.isaimessage(msg)
        return T(msg.content, msg.name, msg.role, Dict{Symbol,Any}(), :assistant)
    elseif PT.istoolmessage(msg)
        return T(msg.content, msg.name, msg.tool_call_id, msg.conversation_id, Dict{Symbol,Any}(), msg.name, :default)
    elseif PT.isaitoolrequest(msg)
        return T(msg.content, msg.name, msg.role, Dict{Symbol,Any}(), :assistant, msg.tool_calls)
    else
        error("Unknown message type: $(typeof(msg))")
    end
end

"""
    tool_output(output::Any)

Convert tool output to string format. This function is used to convert any tool output into a string
representation that can be used in tool messages.

# Behavior
The function handles three cases in order of precedence:
1. AbstractString input: returns the string directly
2. Struct with :output property: returns the output property value as string
3. Other types: converts to string using show method

# Customization
Users can customize how their tool outputs are converted to strings in two ways:

1. Define an :output property in your struct:
```julia
struct MyToolOutput
    output::String  # This will be used automatically
    other_data::Any
end
```

2. Define a custom tool_output method for your type:
```julia
struct MyCustomOutput
    data::Any
end

# Custom conversion method
SwarmAgents.tool_output(x::MyCustomOutput) = "Processed: \$(x.data)"
```

# Examples
```julia
# String passthrough
tool_output("hello")  # returns "hello"

# Struct with output property
struct ResultWithOutput
    output::String
    details::Dict
end
result = ResultWithOutput("computation done", Dict("time" => 0.5))
tool_output(result)  # returns "computation done"

# Custom tool_output method
struct CustomResult
    value::Int
end
SwarmAgents.tool_output(x::CustomResult) = "Result: \$(x.value)"
tool_output(CustomResult(42))  # returns "Result: 42"

# Fallback to show method
tool_output([1, 2, 3])  # returns "[1, 2, 3]"
```

See also: [`handle_tool_calls!`](@ref)
"""
function tool_output(output::Any)
    # Direct passthrough for strings
    output isa AbstractString && return output

    # Check for :output property in structs
    if hasproperty(output, :output)
        return string(getproperty(output, :output))
    end

    # Fallback to show method for other types
    io = IOBuffer()
    show(io, output)
    return String(take!(io))
end

# Export the function
export tool_output
