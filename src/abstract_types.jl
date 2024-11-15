"""
Abstract types for SwarmAgents.jl

This module defines the core abstract types for agents and flow rules.
"""

# Agent abstract types
"""
    AbstractAgent

Base abstract type for all agents in the system. Agents can be either concrete actors
that perform actions or references to other agents.
"""
abstract type AbstractAgent end

"""
    AbstractAgentActor <: AbstractAgent

Abstract type for concrete agent implementations that can perform actions.
These are the actual agents that execute tasks and interact with tools.
"""
abstract type AbstractAgentActor <: AbstractAgent end

"""
    AbstractAgentRef <: AbstractAgent

Abstract type for agent references that point to other agents.
Used to create indirect references and chains of agent responsibilities.
"""
abstract type AbstractAgentRef <: AbstractAgent end

# Flow rules abstract types
"""
    AbstractFlowRules

Base abstract type for all flow control rules in the system.
Flow rules govern how agents interact and how the system progresses.
"""
abstract type AbstractFlowRules end

"""
    AbstractToolFlowRules <: AbstractFlowRules

Abstract type for rules that control tool execution and flow.
These rules determine which tools are allowed to be used at any given point.
"""
abstract type AbstractToolFlowRules <: AbstractFlowRules end

"""
    AbstractTerminationFlowRules <: AbstractFlowRules

Abstract type for rules that determine when to terminate agent execution.
These rules prevent infinite loops and detect completion conditions.
"""
abstract type AbstractTerminationFlowRules <: AbstractFlowRules end
