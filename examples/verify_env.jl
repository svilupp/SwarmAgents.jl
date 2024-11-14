println("Setting up environment...")
using Pkg
Pkg.add("PromptingTools")
using PromptingTools
const PT = PromptingTools

# Set OpenAI API key
println("\nConfiguring OpenAI API key...")
ENV["OPENAI_API_KEY"] = ENV["OPENAI_API_KEY"]  # Use the secret provided
@assert !isempty(ENV["OPENAI_API_KEY"]) "OpenAI API key not set"

# Test PromptingTools with a simple query
println("\nTesting PromptingTools with OpenAI...")
response = aigenerate("Say hello!", model="gpt-3.5-turbo")
println("Test response: ", response.content)

println("\nEnvironment verification complete!")
