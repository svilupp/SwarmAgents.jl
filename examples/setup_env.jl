println("Setting up environment...")
using Pkg
Pkg.add("PromptingTools")
using PromptingTools
const PT = PromptingTools

# Set OpenAI API key from environment
println("Configuring OpenAI API Key...")
ENV["OPENAI_API_KEY"] = get(ENV, "OPENAI_API_KEY", "")  # Ensure it's set
println("OpenAI API Key configured: ", !isempty(ENV["OPENAI_API_KEY"]))

# Test environment
println("\nTesting environment...")
println("PromptingTools version: ", pkgversion(PromptingTools))

# Run all examples
println("\nRunning all examples...")
include("run_all_examples.jl")
