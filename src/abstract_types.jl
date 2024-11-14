# Abstract types for agents
abstract type AbstractAgent end
abstract type AbstractAgentActor <: AbstractAgent end
abstract type AbstractAgentRef <: AbstractAgent end

# Abstract types for flow rules
abstract type AbstractFlowRules end
abstract type AbstractToolFlowRules <: AbstractFlowRules end
abstract type AbstractTerminationFlowRules <: AbstractFlowRules end
