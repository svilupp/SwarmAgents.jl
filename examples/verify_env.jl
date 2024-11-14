println("Setting up environment...")
using Pkg
Pkg.add("PromptingTools")
using PromptingTools
const PT = PromptingTools

# Set OpenAI API key
println("\nConfiguring OpenAI API key...")
api_key = get(ENV, "OPENAI_API_KEY", nothing)
if isnothing(api_key) || isempty(api_key)
    error("OpenAI API key not found in environment variables")
end

# Configure PromptingTools with the API key
PT.set_openai_key(api_key)
println("OpenAI API key configured successfully")

# Test PromptingTools with a simple query
println("\nTesting PromptingTools with OpenAI...")
try
    response = aigenerate("Say hello!", model="gpt-3.5-turbo")
    println("Test response: ", response.content)
    println("\nEnvironment verification complete! ✅")
catch e
    println("\nError testing OpenAI connection:")
    println(e)
    error("Failed to verify OpenAI connection")
end
