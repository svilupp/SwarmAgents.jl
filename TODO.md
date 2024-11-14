# Test File Migration Todo List

## Test Files to Move/Rename
- [x] test/types.jl -> test/test_types.jl (mirrors src/types.jl)
- [x] test/utils.jl -> test/test_utils.jl (mirrors src/utils.jl)
- [x] test/minimal_test.jl -> integrate into appropriate test files based on functionality:
  - Session type tests -> test/test_types.jl (✓ already covered in existing tests)
  - Tool execution tests -> test/test_utils.jl (✓ already covered in existing tests)

## Additional Tasks
- [ ] Create test/test_swarm.jl to mirror src/SwarmAgents.jl for any top-level functionality tests
- [ ] Update runtests.jl to include all new test file names
