# Test script to verify all examples are working correctly
using Pkg
Pkg.activate(".")

println("\n=== Testing OpenAI API Connection ===")
using PromptingTools
using SwarmAgents
const PT = PromptingTools
result = aigenerate("Say hello!", model="gpt-3.5-turbo")
println("API Test Response: ", result.content)

println("\n=== Running Airline Bot Example ===")
println("Testing flight status and flight change functionality...")
include("airline_bot/airline_bot.jl")
run_example()
println("\nAirline Bot Test Complete!")

println("\n=== Running Shoe Store Example ===")
println("Testing authentication flow and inventory queries...")
include("shoe_store/shoe_store_bot.jl")
# Test authentication flow
println("\nTesting authentication flow:")
messages = [
    "show shoes",  # Should prompt for authentication
    "authenticate: jan svilupp, jan@svilupp.github.com",  # Valid authentication
    "show shoes",  # Should show inventory
    "check size 9 Running Shoes"  # Should check size availability
]
run_example(messages)
println("\nShoe Store Test Complete!")

println("\n=== Running Car Analysis Example ===")
println("Testing data analysis and visualization capabilities...")
include("car_analysis/car_analysis.jl")
# Test data analysis capabilities
println("\nTesting data analysis:")
messages = [
    "Can you show me the basic statistics?",
    "Generate some insights about the data",
    "Show me the visualizations"
]
run_example(messages)
println("\nCar Analysis Test Complete!")

println("\n=== All Examples Completed ===")
