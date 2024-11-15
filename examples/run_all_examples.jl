println("Running all examples with OpenAI API integration...")

# Verify environment
using Pkg
using PromptingTools
using SwarmAgents

# Verify API key
@assert haskey(ENV, "OPENAI_API_KEY") "OpenAI API Key not found in environment"
println("OpenAI API Key configured: ", !isnothing(ENV["OPENAI_API_KEY"]))

# Function to safely run examples
function run_example_safely(name, path)
    println("\n=== Testing $name ===")
    try
        # Create a new module for each example
        mod = Module()
        # Add required packages to the module
        Core.eval(mod, :(using SwarmAgents))
        Core.eval(mod, :(using PromptingTools))
        Core.eval(mod, :(using DataFrames))
        Core.eval(mod, :(using PlotlyJS))
        Core.eval(mod, :(using Statistics))
        Core.eval(mod, :(using JSON3))
        Core.eval(mod, :(using Dates))
        # Include the example file in the module's scope
        Base.include(mod, path)
        # Run the example in the module's scope
        if isdefined(mod, :run_example)
            Core.eval(mod, :(run_example()))
            println("✓ $name completed successfully")
            return true
        else
            println("Warning: run_example() not found in $name")
            return false
        end
    catch e
        println("✗ Error in $name: ", e)
        return false
    end
end

# Main function to run all examples
function main()
    examples = [
        ("Airline Bot", "airline_bot/airline_bot.jl"),
        ("Shoe Store Bot", "shoe_store/shoe_store_bot.jl"),
        ("Car Analysis", "car_analysis/car_analysis.jl")
    ]

    success = true
    for (name, path) in examples
        success = success && run_example_safely(name, path)
    end

    if success
        println("\n✓ All examples completed successfully!")
        return 0
    else
        println("\n✗ Some examples failed. Check the logs above for details.")
        return 1
    end
end

# Run main function and exit with its status
exit(main())
