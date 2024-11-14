using SwarmAgents
using DataFrames
using PlotlyJS
using PromptingTools
using Statistics

"""
Example of a data science agent using SwarmAgents.jl
This example demonstrates:
1. Mock dataset creation and analysis
2. Integration with PromptingTools.AICode
3. Statistical analysis with DataFrames
4. Visualization with PlotlyJS
5. Automatic insight generation
"""

# Define our conversation flow rules
struct CarAnalysisFlowRules <: AbstractFlowRules end

"""
Create a mock car dataset
"""
function create_mock_dataset()
    # Create sample data
    brands = ["Toyota", "Honda", "Ford", "BMW", "Tesla"]
    n_cars = 100

    DataFrame(
        brand = rand(brands, n_cars),
        year = rand(2015:2024, n_cars),
        price = round.(rand(20000:80000, n_cars), digits=2),
        mpg = round.(rand(15:50, n_cars), digits=1),
        mileage = rand(1000:150000, n_cars)
    )
end

"""
Generate insights using PromptingTools.AICode
"""
function generate_insights(df::DataFrame)
    prompt = """
    Analyze this car dataset and provide 3 key insights. Use DataFrames.jl functions.
    Available columns: $(names(df))

    Example structure:
    ```julia
    # Calculate average price by brand
    brand_prices = combine(groupby(df, :brand), :price => mean => :avg_price)
    println("Average prices by brand:")
    display(brand_prices)
    ```
    """

    result = PromptingTools.AICode.aigenerate(prompt)
    if !isvalid(result)
        return "Error generating insights"
    end

    # Execute the generated code in the context of our data
    module_with_df = Module()
    Core.eval(module_with_df, :(using DataFrames, Statistics))
    Core.eval(module_with_df, :(df = $df))
    Core.eval(module_with_df, Meta.parse(result.output))

    return result.output
end

"""
Create visualizations using PlotlyJS
"""
function create_visualizations(df::DataFrame)
    # Price distribution by brand
    price_box = Plot(
        df,
        Layout(
            title="Car Prices by Brand",
            yaxis_title="Price ($)",
            boxmode="group"
        ),
        Box(x=:brand, y=:price)
    )

    # MPG vs Price scatter plot
    mpg_scatter = Plot(
        df,
        Layout(
            title="MPG vs Price",
            xaxis_title="MPG",
            yaxis_title="Price ($)"
        ),
        Scatter(x=:mpg, y=:price, mode="markers", marker=attr(color=:brand, colorscale="Viridis"))
    )

    return [price_box, mpg_scatter]
end

"""
Process user message and update context accordingly
"""
function SwarmAgents.process_message(rules::CarAnalysisFlowRules, message::String, context::Dict)
    msg = lowercase(message)

    # First message or reset - create new dataset
    if !haskey(context, "data") || contains(msg, "reset data")
        context["data"] = create_mock_dataset()
        return "Created new mock dataset with $(nrow(context["data"])) cars. Try 'show insights' or 'show plots'!"

    # Show insights
    elseif contains(msg, "show insight")
        insights = generate_insights(context["data"])
        return """
        Here are some insights about the data:

        $insights
        """

    # Show visualizations
    elseif contains(msg, "show plot")
        plots = create_visualizations(context["data"])
        # In a real application, we'd save these plots and return URLs
        return "Generated $(length(plots)) plots: price distribution and MPG vs Price scatter plot"

    # Show basic stats
    elseif contains(msg, "show stat")
        df = context["data"]
        stats = """
        Basic Statistics:
        - Number of cars: $(nrow(df))
        - Average price: \$$(round(mean(df.price), digits=2))
        - Average MPG: $(round(mean(df.mpg), digits=1))
        - Newest car: $(maximum(df.year))
        - Oldest car: $(minimum(df.year))
        """
        return stats

    # Help message
    elseif contains(msg, "help")
        return """
        I can help you analyze car data:
        - Show insights: "show insights"
        - Show plots: "show plots"
        - Show statistics: "show stats"
        - Reset data: "reset data"
        - Get help: "help"
        """

    # Default response
    else
        return "I'm not sure how to help with that. Try asking for 'help' to see what I can do."
    end
end

# Example usage:
function run_example()
    # Initialize the bot with our rules and context
    bot = Agent(
        CarAnalysisFlowRules(),
        Dict{String, Any}()  # Empty context, will be populated on first message
    )

    # Example conversation
    println("Bot: Welcome to the car data analysis bot! I'll create some mock data for analysis.")
    println("Bot: ", process_message(bot, "reset data"))

    println("\nUser: show stats")
    println("Bot: ", process_message(bot, "show stats"))

    println("\nUser: show insights")
    println("Bot: ", process_message(bot, "show insights"))

    println("\nUser: show plots")
    println("Bot: ", process_message(bot, "show plots"))
end

# Run the example if this file is run directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_example()
end
