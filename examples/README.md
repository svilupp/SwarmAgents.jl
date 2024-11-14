# SwarmAgents.jl Examples

This directory contains example implementations demonstrating various capabilities of SwarmAgents.jl.

## Examples Overview

### 1. Airline Customer Service Bot (`airline_bot/`)
A simple customer service bot that demonstrates:
- Basic context management in session
- Flight change functionality
- Flight status queries
- Basic conversation flow with error handling

### 2. Shoe Store Authentication Bot (`shoe_store/`)
Demonstrates authentication flow and protected actions:
- Name and email validation
- Pre-authentication message interception
- Post-authentication capabilities (inventory check, size availability)
- Session state persistence

### 3. Data Science Car Analysis (`car_analysis/`)
Shows integration with data analysis tools:
- Mock car dataset analysis
- Statistical computations using DataFrames.jl
- Visualization with PlotlyJS
- Automatic insight generation using PromptingTools.AICode

## Running the Examples

Each example is self-contained in its directory and can be run independently. Make sure you have SwarmAgents.jl installed:

```julia
using Pkg
Pkg.add("SwarmAgents")
```

Then navigate to the specific example directory and follow the instructions in each example's README.
