# Agent Review Protocol

**MANDATORY PROCESS FOR ALL CODE CHANGES**

## Throughout Implementation

1. **Before starting** - Get ios-architect/backend-architect POV on approach
2. **During implementation** - Consult specialized agents for decisions:
   - backend-architect: API design, schema decisions, data flow
   - ios-architect: SwiftUI patterns, state management, navigation
   - code-reviewer: Code quality, security, performance
3. **Before committing** - Run code-reviewer agent on final code
4. **Before pushing** - Get final approval from relevant specialized agent

## Agent Usage Pattern

```bash
# Start of task
Task(subagent_type: "backend-architect") - Get architectural guidance
Task(subagent_type: "ios-architect") - Get iOS best practices

# During implementation (as needed)
Task(subagent_type: "code-reviewer") - Review specific code patterns

# Before commit
Task(subagent_type: "code-reviewer") - Final comprehensive review

# Run all in parallel when possible
```

## Never Skip Agents

- ❌ Don't implement without agent consultation
- ❌ Don't commit without agent review
- ❌ Don't push without final approval
- ✅ Use agents proactively, not reactively
- ✅ Run agents in parallel when possible
- ✅ Trust agent feedback - they catch critical bugs

## This Prevents

- Memory leaks (iOS 17-26 @Observable bug)
- Race conditions (error handling patterns)
- Schema mismatches (API contracts)
- Security vulnerabilities
- Architecture violations
- Production-breaking bugs

**Last Updated**: 2025-01-05
**Reason**: After missing critical P0 bugs that agents caught
