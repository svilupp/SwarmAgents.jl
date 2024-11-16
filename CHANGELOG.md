# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Improved private agents message visibility:
  - Last turn messages are now visible to all agents
  - Assistant messages with no tool calls are made public
  - Messages during agent handoff are visible
  - Only intermediate tool calls remain private
  - Added comprehensive test suite for privacy logic
- Added `add_transfers!` function to automatically create transfer tools between agents with handover messages

### Fixed
- Simplified tool execution by removing ToolWrapper and tool_impl search, using agent's tool_map directly
- Improved tool filtering with proper handling of duplicates in get_allowed_tools

## [0.2.0]

### Added
- Added PrivateMessage type and agent.private flag to control message visibility between agents
- Implemented flow restrictions to guide proper state transitions and tool usage patterns
- Added termination checks through session to catch issues like tool usage cycles
- Introduced AgentRef to allow referring to agents by symbols for easier agent definitions
- Added customizable progress printing with print_progress and session.io argument (set to nothing to stop printing)

### Fixed
- Messages were not collated correctly when multiple messages were sent in a single request.

## [0.1.0]

- Initial release
