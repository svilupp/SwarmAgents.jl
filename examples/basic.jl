# Basic Example
using SwarmAgents
using PromptingTools
using Dates

"""
Example of basic SwarmAgents.jl functionality demonstrating:
1. Tool usage with clear intent and reflection
2. Multi-agent communication with proper handoffs
3. Context preservation across agent transfers
4. Session-based conversation management
"""

# Ensure OpenAI API key is available
if !haskey(ENV, "OPENAI_API_KEY")
    ENV["OPENAI_API_KEY"] = "$OPENAI_API_KEY"  # Use the secret provided
end

"""
    tell_date(message::String)::String

Get the current date in a human-readable format.

Usage:
    tell_date("What's today's date?")

Intent: Provide current date information for temporal context.
"""
function tell_date(message::String)::String
    return """
    Today's date is $(Dates.today())
    Would you like me to:
    1. Tell you the current time as well
    2. Calculate a specific date
    """
end

"""
    tell_time(message::String)::String

Get the current time in 24-hour format.

Usage:
    tell_time("What time is it?")

Intent: Provide current time information for temporal context.
"""
function tell_time(message::String)::String
    return """
    Current time is $(Dates.format(Dates.now(), "HH:MM:SS"))
    Would you like me to:
    1. Tell you today's date
    2. Set a reminder
    """
end

"""
    wish_happy_birthday(name::String, age::Int)::String

Generate a personalized birthday message.

Usage:
    wish_happy_birthday("Alice", 25)

Intent: Create a warm birthday greeting with personal touch.
"""
function wish_happy_birthday(name::String, age::Int)::String
    return """
    🎉 Happy $(age)th birthday, $(name)! 🎂
    Wishing you a wonderful day filled with joy and celebration!
    """
end

"""
    transfer_to_spanish(message::String, session::Session)::Tuple{Agent,String}

Transfer conversation to Spanish-speaking agent.

Usage:
    transfer_to_spanish("Hola", session)

Intent: Ensure seamless language transition for Spanish speakers.
"""
function transfer_to_spanish(message::String, session::Session)::Tuple{Agent,String}
    spanish_agent = Agent(
        name = "Spanish Agent",
        model = "gpt4o",
        instructions = """
        You are a Spanish-speaking assistant.

        Capabilities:
        - Communicate fluently in Spanish
        - Handle date and time queries in Spanish
        - Transfer to English agent when needed
        - Access conversation context

        What you cannot do:
        - Communicate in languages other than Spanish
        - Modify system settings
        - Access external APIs

        Routine:
        1. Respond to all queries in Spanish
        2. For English requests, transfer to English agent
        3. Maintain professional and friendly tone
        4. Use proper Spanish formality based on context

        Example queries:
        - "¿Qué hora es?" (use tell_time)
        - "¿Qué día es hoy?" (use tell_date)
        - "I need help in English" (transfer to English agent)
        """
    )

    # Add tools with context handling
    add_tools!(spanish_agent, [
        tell_date,
        tell_time,
        transfer_to_english
    ]; hidden_fields=["context"])

    # Share context
    spanish_agent.context = session.context

    handover_message = """
    Transferring you to our Spanish-speaking assistant.
    ---
    Transfiriendo a nuestro asistente de habla hispana.
    """

    return (spanish_agent, handover_message)
end

"""
    transfer_to_english(message::String, session::Session)::Tuple{Agent,String}

Transfer conversation to English-speaking agent.

Usage:
    transfer_to_english("I need English", session)

Intent: Ensure seamless language transition for English speakers.
"""
function transfer_to_english(message::String, session::Session)::Tuple{Agent,String}
    english_agent = Agent(
        name = "English Agent",
        model = "gpt4o",
        instructions = """
        You are an English-speaking assistant.

        Capabilities:
        - Communicate fluently in English
        - Handle date and time queries
        - Transfer to Spanish agent when needed
        - Access conversation context

        What you cannot do:
        - Communicate in languages other than English
        - Modify system settings
        - Access external APIs

        Routine:
        1. Respond to all queries in English
        2. For Spanish requests, transfer to Spanish agent
        3. Maintain professional and friendly tone
        4. Use clear and concise language

        Example queries:
        - "What time is it?" (use tell_time)
        - "What's today's date?" (use tell_date)
        - "¿Hablas español?" (transfer to Spanish agent)
        """
    )

    # Add tools with context handling
    add_tools!(english_agent, [
        tell_date,
        tell_time,
        transfer_to_spanish
    ]; hidden_fields=["context"])

    # Share context
    english_agent.context = session.context

    handover_message = """
    Transferring you to our English-speaking assistant.
    ---
    Cambiando al asistente de habla inglesa.
    """

    return (english_agent, handover_message)
end

# Example usage with proper context handling
function run_example()
    # Create initial English agent
    english_agent = Agent(
        name = "English Agent",
        model = "gpt4o",
        instructions = """
        You are an English-speaking assistant.

        Capabilities:
        - Communicate fluently in English
        - Handle date and time queries
        - Transfer to Spanish agent when needed
        - Access conversation context

        What you cannot do:
        - Communicate in languages other than English
        - Modify system settings
        - Access external APIs

        Routine:
        1. Respond to all queries in English
        2. For Spanish requests, transfer to Spanish agent
        3. Maintain professional and friendly tone
        4. Use clear and concise language

        Example queries:
        - "What time is it?" (use tell_time)
        - "What's today's date?" (use tell_date)
        - "¿Hablas español?" (transfer to Spanish agent)
        """
    )

    # Add tools with context handling
    add_tools!(english_agent, [
        tell_date,
        tell_time,
        transfer_to_spanish
    ]; hidden_fields=["context"])

    # Initialize session with context
    context = Dict{Symbol,Any}(
        :context => Dict{Symbol,Any}(
            :language_preference => "English",
            :conversation_start => now()
        )
    )
    session = Session(english_agent; context=context)

    # Example conversation
    println("Bot: Hello! I'm your multilingual assistant. How can I help you today?\n")

    messages = [
        "What time is it?",
        "¿Hablas español?",
        "¿Qué hora es?",
        "I need English please",
        "What's today's date?"
    ]

    for msg in messages
        println("\nUser: $msg")
        result = run_full_turn!(session, msg)

        # Handle agent transfers
        if result isa Tuple{Agent,String}
            new_agent, handover_msg = result
            println("\nBot: $handover_msg")
            session = Session(new_agent; context=session.context)
        end
    end
end

# Run the example if this file is run directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_example()
end
