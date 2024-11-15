using SwarmAgents
using DataFrames
using PlotlyJS
using PromptingTools
using Statistics

# Ensure OpenAI API key is available
if !haskey(ENV, "OPENAI_API_KEY")
    error("OpenAI API key not found in environment variables. Please set the OPENAI_API_KEY environment variable.")
end

"""
Example of a data science agent using SwarmAgents.jl
This example demonstrates:
1. Mock dataset creation and analysis
2. Integration with PromptingTools.AICode
3. Statistical analysis with DataFrames
4. Visualization with PlotlyJS
5. Automatic insight generation
"""

# Removed parameter structs and flow rules

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
"""
    show_stats(message::String, session::Session)::String

Display comprehensive statistics about the car dataset, including price, mpg, and mileage metrics.

Usage:
    show_stats("Show me the statistics", session)

Intent: Provide a clear numerical overview of the dataset's key metrics.
"""
function show_stats(message::String, session::Session)::String
    df = session.context[:data]
    stats = describe(df, :mean, :std, :min, :max)
    return "Here are the detailed statistics for our car dataset:\n$(stats)\n\nWould you like to explore any specific metrics in more detail?"
end

"""
    show_insights(message::String, session::Session)::String

Generate AI-powered insights about patterns and trends in the car dataset.

Usage:
    show_insights("What patterns do you see?", session)

Intent: Discover and communicate meaningful patterns in the data using AI analysis.
"""
function show_insights(message::String, session::Session)::String
    df = session.context[:data]
    insights = generate_insights(df)
    return "I've analyzed the data and found these interesting patterns:\n$(insights)\n\nWould you like me to create visualizations to illustrate these insights?"
end

"""
    show_plots(message::String, session::Session)::String

Create and display interactive visualizations of price distributions and relationships.

Usage:
    show_plots("Show me some charts", session)

Intent: Visualize key relationships and distributions to aid understanding.
"""
function show_plots(message::String, session::Session)::String
    df = session.context[:data]
    plots = create_visualizations(df)
    return "I've created interactive visualizations showing:\n1. Price distribution by brand\n2. MPG vs Price relationship\n\nWould you like to explore any specific aspects of these visualizations?"
end

"""
    transfer_to_visualization(message::String, session::Session)::Tuple{Agent,String}

Transfer control to the visualization specialist agent for detailed plot analysis and customization.

Usage:
    transfer_to_visualization("I need detailed plot analysis", session)

Intent: Hand off to a specialized agent for in-depth visualization work.
"""
function transfer_to_visualization(message::String, session::Session)::Tuple{Agent,String}
    # Create visualization specialist agent
    viz_agent = Agent(;
        name = "Visualization Specialist",
        model = "gpt4o",  # Use OpenAI GPT-4 model
        instructions = """
        You are a visualization specialist focused on creating and explaining data visualizations.

        Capabilities:
        - Create interactive plots using PlotlyJS
        - Explain visualization insights
        - Guide users through data interpretation
        - Customize visualizations based on user needs
        - Transfer back to main agent when visualization work is complete

        Routines:
        1. For plot creation:
           - Use show_plots to generate visualizations
           - Explain each visual element
           - Highlight key patterns and outliers

        2. For customization requests:
           - Modify plot parameters
           - Adjust visual elements for clarity
           - Ensure accessibility

        3. For completion:
           - Use transfer_back_to_main when visualization work is done
           - Provide summary of changes and insights

        Always explain visualizations in clear terms and suggest ways to explore the data further.
        """
    )

    # Add visualization-specific tools
    add_tools!(viz_agent, [
        show_plots,
        transfer_back_to_main
    ]; hidden_fields=["context"])

    # Share context with new agent
    viz_agent.context = session.context

    handover_message = """
    I'm transferring you to our visualization specialist who can help with detailed plot analysis and customization.
    Current dataset has $(nrow(session.context[:data])) records with columns: $(names(session.context[:data])).
    """

    return (viz_agent, handover_message)
end

"""
    transfer_back_to_main(message::String, session::Session)::Tuple{Agent,String}

Transfer control back to the main car analysis agent.

Usage:
    transfer_back_to_main("Return to main analysis", session)

Intent: Hand off back to main agent for general analysis tasks.
"""
function transfer_back_to_main(message::String, session::Session)::Tuple{Agent,String}
    # Create main analysis agent
    main_agent = Agent(;
        name = "Car Analysis Bot",
        model = "gpt4o",
        instructions = """
        You are a data science agent specialized in analyzing car data.
        [Previous instructions will be copied here during actual implementation]
        """
    )

    # Add all tools to the main agent
    add_tools!(main_agent, [
        show_stats,
        show_insights,
        show_plots,
        reset_data,
        transfer_to_visualization
    ]; hidden_fields=["context"])

    # Share context with new agent
    main_agent.context = session.context

    handover_message = """
    Returning to the main analysis agent for general car data analysis.
    Current dataset has $(nrow(session.context[:data])) records.
    """

    return (main_agent, handover_message)
end

"""
    reset_data(message::String, session::Session)::String

Usage:
    reset_data("Generate new data", session)

Intent: Refresh the dataset with new random samples for testing different scenarios.
"""
function reset_data(message::String, session::Session)::String
    session.context[:data] = create_mock_dataset()
    return "I've generated a new random dataset with $(nrow(session.context[:data])) cars. Would you like to see the basic statistics of this new dataset?"
end

# Example usage
function run_example(custom_messages=nothing)
    # Create agent with analysis capabilities
    agent = Agent(;
        name = "Car Analysis Bot",
        model = "gpt4o",  # Use OpenAI GPT-4 model
        instructions = """
        You are a data science agent specialized in analyzing car data.

        Capabilities:
        - Generate statistical summaries of car data (means, std devs, ranges)
        - Create interactive visualizations using PlotlyJS
        - Discover patterns and insights using AI analysis
        - Refresh dataset with new random samples
        - Transfer to visualization specialist for detailed plot analysis

        Routines:
        1. For statistics requests:
           - Use show_stats to provide numerical summaries
           - Explain key metrics in plain language
           - Suggest relevant follow-up analyses

        2. For insight requests:
           - Use show_insights to analyze patterns
           - Connect findings to business implications
           - Recommend relevant visualizations

        3. For visualization requests:
           - Use show_plots for basic visual analysis
           - For detailed visualization needs, transfer to visualization specialist
           - Guide user through interpretation

        4. For data refresh:
           - Use reset_data to generate new samples
           - Automatically show basic stats of new data
           - Compare with previous dataset if relevant

        5. For specialized visualization needs:
           - Use transfer_to_visualization to hand off to visualization expert
           - Provide context and current analysis state
           - Let specialist handle detailed customization

        Always explain findings in clear, non-technical language and suggest next steps.
        When visualization needs become complex, transfer to the visualization specialist.
        """
    )

    # Add tools to the agent
    add_tools!(agent, [
        show_stats,
        show_insights,
        show_plots,
        reset_data,
        transfer_to_visualization
    ]; hidden_fields=["context"])

    # Initialize context with fresh data
    context = Dict{String,Any}()
    reset_data("Initialize data", Session(agent; context=context))

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
        result = run_full_turn!(session, msg)

        # Check if we need to transfer to visualization specialist
        if result isa Tuple{Agent,String}
            new_agent, handover_msg = result
            println("\nBot: $handover_msg")
            # Create new session with visualization specialist
            session = Session(new_agent; context=session.context)
            println("\nVisualization Specialist: Ready to help with detailed visualization analysis. What would you like to explore?")
        end
    end

    return true
end

# Run the example if this file is run directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_example()
end
