# Setup OpenAI API key for PromptingTools
using PromptingTools
const PT = PromptingTools

# Set OpenAI API key from environment variable
const OPENAI_API_KEY = ENV["OPENAI_API_KEY"]
PT.set_openai_key(OPENAI_API_KEY)

# Test the connection
result = aigenerate("Say hello!", model="gpt-3.5-turbo")
@assert !isnothing(result.content) "Failed to connect to OpenAI API"
println("OpenAI API connection test successful!")
