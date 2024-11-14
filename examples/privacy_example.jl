using SwarmAgents
using PromptingTools
const PT = PromptingTools

# Create a private agent that will keep its messages private
private_agent = Agent(
    name = "PrivateAgent",
    instructions = "You are a private agent. Your messages are only visible to you.",
    private = true
)

# Create a public agent that will have public messages
public_agent = Agent(
    name = "PublicAgent",
    instructions = "You are a public agent. Your messages are visible to everyone."
)

# Define some example tools
get_secret() = "This is a secret message"
get_public_info() = "This is public information"

# Add tools to both agents
add_tools!(private_agent, get_secret)
add_tools!(public_agent, get_public_info)

# Initialize a session with the private agent
session = Session(private_agent)

# Run a turn that will create a private message
println("\n=== Private Agent Turn ===")
run_full_turn!(session, "Get the secret message")

# Switch to public agent
session.agent = public_agent

# Run a turn with the public agent - it won't see private agent's messages
println("\n=== Public Agent Turn ===")
run_full_turn!(session, "What was the secret message?")

# Switch back to private agent - it can see its own messages
println("\n=== Private Agent Turn Again ===")
session.agent = private_agent
run_full_turn!(session, "What messages can you see in the history?")
