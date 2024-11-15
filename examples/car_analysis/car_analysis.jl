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
struct CarAnalysisFlowRules <: AbstractToolFlowRules end

# Define tool parameters
Base.@kwdef struct ShowStatsParams
    none::Nothing = nothing
end

Base.@kwdef struct ShowInsightsParams
    none::Nothing = nothing
end

Base.@kwdef struct ShowPlotsParams
    none::Nothing = nothing
end

Base.@kwdef struct ResetDataParams
    none::Nothing = nothing
end

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
            yaxis_title=r"Price ($)",
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
            yaxis_title=r"Price ($)"
        ),
        Scatter(x=:mpg, y=:price, mode="markers", marker=attr(color=:brand, colorscale="Viridis"))
    )

    return [price_box, mpg_scatter]
end

# Tool functions
function show_stats(params::ShowStatsParams, context::Dict)
    if !haskey(context, "data")
        return "No data available. Please reset the data first."
    end

    df = context["data"]
    return """
    Basic Statistics:
    - Number of cars: $(nrow(df))
    - Average price: \$$(round(mean(df.price), digits=2))
    - Average MPG: $(round(mean(df.mpg), digits=1))
    - Newest car: $(maximum(df.year))
    - Oldest car: $(minimum(df.year))
    """
end

function show_insights(params::ShowInsightsParams, context::Dict)
    if !haskey(context, "data")
        return "No data available. Please reset the data first."
    end

    insights = generate_insights(context["data"])
    return """
    Here are some insights about the data:

    $insights
    """
end

function show_plots(params::ShowPlotsParams, context::Dict)
    if !haskey(context, "data")
        return "No data available. Please reset the data first."
    end

    plots = create_visualizations(context["data"])
    return "Generated $(length(plots)) plots: price distribution and MPG vs Price scatter plot"
end

function reset_data(params::ResetDataParams, context::Dict)
    context["data"] = create_mock_dataset()
    return "Created new mock dataset with $(nrow(context["data"])) cars. Try 'show insights' or 'show plots'!"
end

# Example usage
function run_example(custom_messages=nothing)
    # Create agent with analysis capabilities
    agent = Agent(;
        name = "Car Analysis Bot",
        model = "gpt-3.5-turbo",  # Use OpenAI GPT-3.5
        instructions = """
        You are a data science agent specialized in analyzing car data.
        You can:
        - Show basic statistics
        - Generate insights
        - Create visualizations
        Use the available tools to assist users.
        """
    )

    # Add tools to the agent
    add_tools!(agent, [
        Tool((msg, session) -> show_stats(ShowStatsParams(), session.context)),
        Tool((msg, session) -> show_insights(ShowInsightsParams(), session.context)),
        Tool((msg, session) -> show_plots(ShowPlotsParams(), session.context)),
        Tool((msg, session) -> reset_data(ResetDataParams(), session.context))
    ])

    # Initialize context with fresh data
    context = Dict{String,Any}()
    reset_data(ResetDataParams(), context)

    # Create session
    session = Session(agent; context=context)

    # Example conversation
    println("Bot: Welcome to the car data analysis bot! Let's analyze some car data.")

    # Use custom messages if provided, otherwise use default messages
    messages = custom_messages !== nothing ? custom_messages : [
        "Can you show me the basic statistics?",
        "Generate some insights about the data",
        "Show me the visualizations"
    ]

    for msg in messages
        println("\nUser: $msg")
        run_full_turn!(session, msg)
    end

    return true
end

# Run the example if this file is run directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_example()
end
