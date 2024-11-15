# Set up environment and run airline bot example
using Pkg
Pkg.activate(".")

println("Setting up environment...")

# Set OpenAI API key
ENV["OPENAI_API_KEY"] = ENV["OPENAI_API_KEY"]
println("OpenAI API Key set: ", !isempty(ENV["OPENAI_API_KEY"]))

# Load required packages
println("Loading packages...")
using SwarmAgents
using PromptingTools
const PT = PromptingTools

println("\nStarting airline bot example...")
# Run the example
include("airline_bot/airline_bot.jl")
println("\nExecuting airline bot example...")
run_example()
