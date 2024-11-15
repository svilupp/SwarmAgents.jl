# Triage Agent Example
using SwarmAgents
using PromptingTools
using Dates

"""
Example of a multi-agent customer service system using SwarmAgents.jl
This system demonstrates:
1. Specialized agents for different tasks (triage, sales, refunds)
2. Seamless agent transfers with context preservation
3. Clear tool definitions with intent and reflection
4. Proper context handling with hidden fields
"""

"""
    process_refund(item_id::String, reason::String)::String

Process a refund request for a specific item.
Returns confirmation message with refund status.

Usage:
    process_refund("item_123", "defective product")

Intent: Handle customer refund request and update order status.
"""
function process_refund(item_id::String, reason::String)::String
    # In a real implementation, this would call your payment processor's API
    return """
    Refund processed successfully for item $item_id
    Reason: $reason
    Refund ID: REF_$(rand(1000:9999))
    Status: Completed
    """
end

"""
    apply_discount(message::String)::String

Apply a discount to the customer's cart.
Returns confirmation with discount details.

Usage:
    apply_discount("apply standard discount")

Intent: Process discount application as compensation or courtesy.
"""
function apply_discount(message::String)::String
    # In a real implementation, this would interact with your e-commerce system
    discount = 15  # Example discount percentage
    return """
    Applied $(discount)% courtesy discount to your cart
    Please proceed to checkout to use this discount
    Valid for: 24 hours
    """
end

"""
    transfer_to_triage(message::String)::Tuple{Agent,String}

Transfer customer back to triage for reassessment.
Returns triage agent instance and handover message.

Usage:
    transfer_to_triage("need different department")

Intent: Return customer to triage for proper routing.
"""
function transfer_to_triage(message::String)::Tuple{Agent,String}
    context = current_session().context[:context]

    handover_message = """
    Transferring you back to our Triage Agent.
    They'll help direct you to the right department.

    Previous department: $(current_session().agent.name)
    Request: $message
    """

    return (triage_agent, handover_message)
end

"""
    transfer_to_sales(message::String)::Tuple{Agent,String}

Transfer customer to sales department.
Returns sales agent instance and handover message.

Usage:
    transfer_to_sales("interested in purchasing")

Intent: Connect customer with sales specialist.
"""
function transfer_to_sales(message::String)::Tuple{Agent,String}
    context = current_session().context[:context]

    handover_message = """
    Transferring you to our Sales Department.
    They'll help you with your purchase!

    Request: $message
    """

    return (sales_agent, handover_message)
end

"""
    transfer_to_refunds(message::String)::Tuple{Agent,String}

Transfer customer to refunds department.
Returns refunds agent instance and handover message.

Usage:
    transfer_to_refunds("need refund for item")

Intent: Connect customer with refunds specialist.
"""
function transfer_to_refunds(message::String)::Tuple{Agent,String}
    context = current_session().context[:context]

    handover_message = """
    Transferring you to our Refunds Department.
    They'll help process your refund request.

    Request: $message
    """

    return (refunds_agent, handover_message)
end

# Define the agents with detailed instructions
triage_agent = Agent(
    name = "Triage Agent",
    model = "gpt4o",
    instructions = """
    You are a triage agent responsible for routing customers to the right department.

    What you can do:
    - Analyze customer requests and determine appropriate department
    - Transfer to Sales for purchase inquiries
    - Transfer to Refunds for refund requests
    - Access customer context for informed routing

    What you cannot do:
    - Process refunds directly
    - Handle sales transactions
    - Modify customer records

    Routine:
    1. Analyze customer's initial request
    2. Identify the most appropriate department
    3. Transfer to correct specialist with context
    4. Provide clear handover message
    5. Maintain professional and helpful tone

    Example queries:
    - "I want to buy something" (transfer to sales)
    - "I need a refund" (transfer to refunds)
    - "My item is broken" (transfer to refunds)
    """
)

sales_agent = Agent(
    name = "Sales Agent",
    model = "gpt4o",
    instructions = """
    You are a sales specialist helping customers with purchases.

    What you can do:
    - Provide product information
    - Answer pricing questions
    - Handle purchase inquiries
    - Transfer back to triage if needed

    What you cannot do:
    - Process refunds
    - Modify prices
    - Create new products

    Routine:
    1. Understand customer's purchase needs
    2. Provide relevant product details
    3. Guide through purchase process
    4. Transfer to triage if different help needed
    5. Maintain enthusiastic and helpful tone

    Example queries:
    - "Tell me about your products"
    - "How much does it cost?"
    - "I need a refund" (transfer to triage)
    """
)

refunds_agent = Agent(
    name = "Refunds Agent",
    model = "gpt4o",
    instructions = """
    You are a refunds specialist helping customers with refund requests.

    What you can do:
    - Process refund requests
    - Apply courtesy discounts
    - Verify refund eligibility
    - Transfer back to triage if needed

    What you cannot do:
    - Create new orders
    - Modify prices
    - Change product information

    Routine:
    1. Verify refund request details
    2. Offer discount as alternative if appropriate
    3. Process refund if customer insists
    4. Transfer to triage if different help needed
    5. Maintain professional and empathetic tone

    Example queries:
    - "I want a refund for item_123"
    - "My product is defective"
    - "I want to buy something" (transfer to triage)
    """
)

# Add tools to agents with hidden fields for context
add_tools!(triage_agent, [
    transfer_to_sales,
    transfer_to_refunds
]; hidden_fields=["context"])

add_tools!(sales_agent, [
    transfer_to_triage
]; hidden_fields=["context"])

add_tools!(refunds_agent, [
    process_refund,
    apply_discount,
    transfer_to_triage
]; hidden_fields=["context"])

# Initialize session with context
function run_example()
    # Set up OpenAI API key from environment
    if !haskey(ENV, "OPENAI_API_KEY")
        ENV["OPENAI_API_KEY"] = "$OPENAI_API_KEY"  # Use the secret provided
    end

    # Initialize session with triage agent
    sess = Session(triage_agent)

    # Set initial context
    sess.context = Dict{Symbol,Any}(
        :context => Dict{Symbol,Any}(
            :customer_id => "CUST123",
            :order_history => ["ORD456", "ORD789"]
        )
    )

    # Run example conversation
    println("Bot: Welcome! How can I help you today?\n")

    # Example conversation flow
    messages = [
        "I want to buy something",
        "Actually, I need a refund for item_123",
        "Yes, please process the refund. It's defective."
    ]

    for msg in messages
        println("\nUser: $msg")
        run_full_turn!(sess, msg)
    end
end

# Run the example if this file is run directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_example()
end
