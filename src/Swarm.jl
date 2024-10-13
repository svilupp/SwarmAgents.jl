module Swarm

# Write your package code here.

export AbstractTool, AbstractAgent
abstract type AbstractTool end
abstract type AbstractAgent end

export Agent, Response, Result
Base.@kwdef struct Agent <: AbstractAgent
    name::String
    model::String = "gpt-4o"
    instructions::String = "You are a helpful agent."
    functions::Vector{Type} = Type[]
    tool_choice::Union{String, Nothing} = nothing
    parallel_tool_calls::Bool = false
end

Base.@kwdef struct Response
    messages::Vector = PT.AbstractChatMessage[]
    agent::Union{Agent, Nothing} = nothing
    context_variables::Dict = Dict()
end

"""
Encapsulates the possible return values for an agent function.

Attributes:
    value (str): The result value as a string.
    agent (Agent): The agent instance, if applicable.
    context_variables (dict): A dictionary of context variables.
"""
Base.@kwdef struct Result
    value::String = ""
    agent::Union{Agent, Nothing} = nothing
    context_variables::Dict = Dict()
end

## JSON3 serialization
JSON3.StructTypes.StructType(::Type{<:AbstractTool}) = JSON3.StructTypes.Struct()
JSON3.StructTypes.StructType(::Type{<:AbstractAgent}) = JSON3.StructTypes.Struct()
end # module