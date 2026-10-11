# The agent as witness

The core rule of ghosted: **dumb shell decides, agents compose.**

An AI agent is a terrible watchdog — it only exists when invoked, it can
hallucinate, and "did the user show up this month?" must not depend on
inference. But an agent is a *great* witness: when you finally come back (or
when a stage-2 draft needs finishing), it can read the switch state, tell you
what tripped, and help write the human message.

Drop the block below into your agent harness's instructions file
(`AGENTS.md`, `CLAUDE.md`, or equivalent):

```markdown
## ghosted (dead man's switch)

`~/.ghosted/` holds a dead man's switch (watchdog: systemd user timer
`ghosted-check.timer`; heartbeat = agent session activity).

Session-start checks:
- If `~/.ghosted/ALERT` exists: tell the user it tripped (stage + last
  activity) and suggest `alive` to clear it.
- If `~/.ghosted/CONTACT-DRAFT.md` exists (stage 2): offer to finalize the
  emergency-contact message from it. Never send anything yourself.
- Never reset switch state yourself. Only the user runs `alive`.
```

That last line matters: the agent that witnesses the switch must never hold
the match that resets it.

## Option B: be the channel

Instead of (or in addition to) checking at session start, an agent can be a
*delivery target*. The `agent` channel pipes a witness prompt — the alert,
your emergency-note draft, and compose-only rules — into any command's stdin:

```sh
# ~/.config/ghosted/config
CHANNELS="agent"
AGENT_CMD="ssh witness@otherbox my-agent --prompt-stdin"
```

The prompt tells the receiving agent exactly what it may and may not do:
compose the contact message, never send it, never touch switch state. Same
rule on both ends — dumb shell decides, agents compose.
