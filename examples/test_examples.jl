println("Setting up environment...")
using Pkg
Pkg.instantiate()
using SwarmAgents
using PromptingTools
const PT = PromptingTools

# Set OpenAI API key
println("\nOpenAI API Key status: ", !isnothing(ENV["OPENAI_API_KEY"]))

println("\nTesting Airline Bot:")
include("airline_bot/airline_bot.jl")
println("Running airline bot example...")
run_example()
