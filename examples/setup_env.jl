println("Setting up environment...")
using Pkg
Pkg.activate(".")

# Install required packages if not already installed
packages = [
    "PromptingTools",
    "SwarmAgents",
    "DataFrames",
    "PlotlyJS",
    "Statistics",
    "JSON3"
]

for pkg in packages
    if !haskey(Pkg.project().dependencies, pkg)
        println("Installing $pkg...")
        Pkg.add(pkg)
    end
end

using PromptingTools
const PT = PromptingTools

# Configure OpenAI API key
println("\nConfiguring OpenAI API key...")
api_key = get(ENV, "OPENAI_API_KEY", nothing)
if isnothing(api_key) || isempty(api_key)
    error("OpenAI API key not found in environment variables")
end

# Test PromptingTools with a simple query
println("\nTesting PromptingTools with OpenAI...")
try
    response = aigenerate("Say hello!", model="gpt-3.5-turbo")
    println("Test response: ", response.content)
    println("\nEnvironment setup complete! ✅")
catch e
    println("\nError testing OpenAI connection:")
    println(e)
    error("Failed to verify OpenAI connection")
end

# Run all examples
println("\nRunning all examples...")
include("run_all_examples.jl")
