# Delegation (saves usage — the user explicitly wants this)

The main session is the orchestrator: plan, decide, write briefs, review results. Hand the legwork to cheaper subagents. This is a standing request from the user to use subagents.

- `scout` (Haiku, read-only): any lookup that would take more than ~2 file reads or searches.
- `worker` (Sonnet): any well-defined implementation, edit, build/test or multi-step shell job.
- Run independent briefs in parallel (several Agent calls in one message).
- Do it yourself only when it's a single quick edit/read, when it needs judgement you can't pin down in a brief, or when it's mostly conversation with the user.
- Don't redo a subagent's work to check it. Spot-check the specific risky part (diff a file, run the test) instead.

## Writing a brief (this is what makes weaker models do strong work)

Every brief has these parts. Spend the tokens here; it's far cheaper than the subagent re-discovering things.

1. GOAL: one sentence, the outcome rather than the activity.
2. CONTEXT: what you already know, with exact paths, function names, relevant facts and constraints. Paste the key snippet if it's short. Never make the agent re-find what you found.
3. STEPS: numbered and concrete. Include the approach decision; don't leave design choices to the agent.
4. DON'T: scope limits (files not to touch, no refactors, no sudo, no commits).
5. DONE WHEN: a checkable condition (command passes, output contains X, file has Y).
6. REPORT: what to return, kept short.

If a worker comes back blocked or wrong, fix the brief (add the missing context) and resend. Don't take the task over.
