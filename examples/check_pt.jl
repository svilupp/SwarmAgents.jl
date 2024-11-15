println("Checking PromptingTools configuration...")
using Pkg
Pkg.activate(".")
using PromptingTools

println("\nPromptingTools loaded successfully")
println("\nChecking module contents:")
for name in names(PromptingTools)
    println(name)
end

# Try to access configuration
println("\nTrying to access configuration:")
try
    @show PromptingTools.CONFIG
catch e
    println("Error accessing CONFIG: ", e)
end

# Try to set OpenAI key directly
println("\nTrying to set OpenAI key:")
try
    ENV["OPENAI_API_KEY"] = ENV["OPENAI_API_KEY"]
    @show haskey(ENV, "OPENAI_API_KEY")
catch e
    println("Error setting OpenAI key: ", e)
end
