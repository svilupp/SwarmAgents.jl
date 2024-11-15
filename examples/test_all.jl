# Test script to verify all examples are working correctly
using Pkg
Pkg.activate(".")

println("\n=== Testing OpenAI API Connection ===")
using PromptingTools
const PT = PromptingTools
result = aigenerate("Say hello!", model="gpt-3.5-turbo")
println("API Test Response: ", result.content)

println("\n=== Running Airline Bot Example ===")
println("Testing flight status and flight change functionality...")
include("airline_bot/airline_bot.jl")

println("\n=== Running Shoe Store Example ===")
println("Testing authentication flow and inventory queries...")
include("shoe_store/shoe_store_bot.jl")

println("\n=== Running Car Analysis Example ===")
println("Testing data analysis and visualization capabilities...")
include("car_analysis/car_analysis.jl")

println("\n=== All Examples Completed ===")
