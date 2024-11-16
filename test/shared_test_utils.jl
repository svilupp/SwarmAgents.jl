using Test
using SwarmAgents
using PromptingTools

# Shared test structures
struct TestStructWithOutput
    output::String
    data::Int
end

struct TestStructNoOutput
    value::String
    TestStructNoOutput(value::String) = new(value)
    TestStructNoOutput(value::Any) = new(string(value))
end

struct TestStructCustomOutput
    data::String
end

# Define custom tool_output method
SwarmAgents.tool_output(x::TestStructCustomOutput) = "Custom: $(x.data)"

# Shared test functions
func1() = nothing
func5() = "test"
func_struct_output() = TestStructWithOutput("struct output", 42)
func_no_output() = TestStructNoOutput("custom value")
