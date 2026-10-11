# ghosted

**A dead man's switch for the AI era.**

You talk to a local AI agent every day — it runs on your machine, on your
hardware, and it knows your projects better than most people do. But if you
stopped showing up tomorrow, nothing on that machine would notice.

ghosted notices.

[![CI](https://github.com/Central-California-Health-Foundation/ghosted/actions/workflows/ci.yml/badge.svg)](https://github.com/Central-California-Health-Foundation/ghosted/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![shell: bash](https://img.shields.io/badge/shell-bash%20%C2%B7%20zero%20deps-blue)]()

## Why

I run a local LLM and work with my agent nearly every day. One night it hit
me: if I ever went more than a month without touching it, something would be
wrong with *me* — and my setup, the thing with the most continuous signal of my
daily life, wouldn't say a word.

So: make the agent usage itself the proof of life. If the sessions stop, the
machine escalates — first nagging me, then waking up my emergency note. No
cloud account, no agent, no daemon of its own beyond a systemd timer.

## How it works

```
     heartbeat (implicit)                  watchdog (dumb shell)
 ┌────────────────────────────┐   daily   ┌───────────────────────────┐
 │ any file activity under    │──────────▶│ age = now − newest mtime  │
 │ your agent's session dirs  │ read-only │ reads only — can never    │
 │ e.g. ~/.dsh/sessions       │           │ reset its own timer       │
 └────────────────────────────┘           └─────┬─────────┬────────┬──┘
                                        age<30d │  age≥30 │ age≥37 │
                                            ┌───▼───┐ ┌───▼────┐ ┌─▼──────────┐
                                            │  OK   │ │ STAGE 1│ │  STAGE 2   │
                                            │ heal  │ │ alert  │ │ contact    │
                                            │       │ │  you   │ │ draft+send │
                                            └───────┘ └───┬────┘ └────────────┘
                                                   `alive` clears it
```

1. **Heartbeat, implicit.** No wrapper scripts, no hooks. Any ordinary use of
   your tools bumps file mtimes; ghosted watches the newest one under
   `HEARTBEAT_PATHS` (your agent's session store is the obvious choice).
2. **Watchdog, dumb.** A systemd user timer runs `ghosted check` daily. It is
   plain bash: no network, no LLM, nothing that can hallucinate or OOM. It
   only *reads* heartbeat paths — it can never reset its own timer.
3. **A ladder, not a guillotine.** 30 days silent → an `ALERT` file and your
   notify hook fire (stage 1). 37 days → the contact stage: your emergency
   note is prepared as a draft for delivery (stage 2).
4. **Self-healing.** Come back on day 33 and use your agent like normal — the
   next check recovers the switch automatically. `alive` is there for the
   "I'm about to be quiet on purpose" moments.

## Quickstart

```sh
git clone https://github.com/Central-California-Health-Foundation/ghosted
cd ghosted
./install.sh                # no sudo; installs to ~/.local/bin + systemd user timer
```

Then:

1. `~/.config/ghosted/config` — point `HEARTBEAT_PATHS` at something you touch
   daily (DSH, Claude Code, ollama, any session dir — see the examples inside).
2. `~/.ghosted/note.md` — fill in the emergency note your contact will receive.
3. `ghosted status` — see where you stand:

```
ghosted 0.1.0
  state dir     : /home/grant/.ghosted
  heartbeats    : /home/grant/.dsh/sessions
  notify hook   : not wired (local-only; see notify.sh.example)
  last activity : 2026-10-11T07:43:02+00:00  (0d ago)
  stage         : 0  (stage 1 @ 30d, stage 2 @ 37d)
  next trip     : in 30d of silence
```

## The ladder

| Silence | Stage | What happens |
|---------|-------|--------------|
| < 30 d  | 0     | Nothing. Normal use keeps everything green and heals earlier alerts. |
| ≥ 30 d  | 1     | `~/.ghosted/ALERT` written, notify hook fires. You get a grace window to `alive`. |
| ≥ 37 d  | 2     | `note.md` becomes `CONTACT-DRAFT.md`, notify hook fires with the contact stage. |

Thresholds are config (`GRACE_AFTER`, `CONTACT_AFTER`). Stages fire **once**
each — no nag spam.

## Delivery is a hook, not a dependency

Out of the box ghosted is **local-only**: alerts are files, which is honest —
it won't pretend to reach your phone before you've configured anything. Wire
up delivery by copying `examples/notify.sh.example` to `~/.ghosted/notify.sh`
and `chmod +x`:

```sh
# ntfy.sh push — free, no account, one curl
curl -fsS -H "Title: ghosted (stage $1)" -d "$msg" https://ntfy.sh/YOUR-SECRET-TOPIC
# or email
msmtp -a contact "$(cat ~/.ghosted/contact.txt)" <"$4"
```

## The agent as witness

The fun part: your AI agent can be the *witness*, never the *judge*. The
decision to fire lives entirely in dumb shell; the agent only helps compose
the stage-2 message from your note when you next show up. Drop the snippet in
[docs/agent-witness.md](docs/agent-witness.md) into your `AGENTS.md` /
`CLAUDE.md` and any harness that reads it (DSH, Claude Code, …) will notice a
tripped switch at session start — and will never be trusted to reset it.

## Design principles

1. **Dumb shell decides; agents compose.** The trigger must not depend on
   anything that can crash, rate-limit, or hallucinate.
2. **The watchdog only reads.** It can never accidentally reset itself.
3. **Staged escalation.** False positives (flu week, cabin trip) should cost
   you one `alive`, not an embarrassing call to your mother.
4. **Local-first.** Zero accounts, zero network. Delivery is opt-in glue.

## Limitations — read before relying on it

- **Machine off = watchdog off.** A purely local switch can't fire if the
  emergency is the machine itself (power loss, theft). If that matters, add a
  daily proof-of-life ping to an external observer (healthchecks.io, or a
  friend's Pi) — absence of the ping fires there even when the house is dark.
- **This is not a medical or safety device.** It's a nudge with a ladder.
  See [SECURITY.md](SECURITY.md).

## FAQ

**Why not just use healthchecks.io?** It's great, and the ping pattern covers
the machine-off case. ghosted's difference: the heartbeat is *implicit* in
tool you already use daily, escalation is staged with a grace window, and the
whole decision loop stays on your box.

**Why bash?** The watchdog's job is to outlive everything clever. It's ~200
lines, shellcheck-clean, and has an integration test that drives the full
ladder with fake mtimes (`bash tests/test.sh`).

**Why a systemd user timer instead of cron?** Linger keeps it running when
you're logged out, `Persistent=true` catches up missed runs after downtime,
and cron daemons are frequently absent on minimal systems. (install.sh falls
back to printing a cron line when systemd isn't around.)

## Development

```sh
bash tests/test.sh    # full ladder: fresh → stage 1 → stage 2 → recovery → ack
shellcheck bin/ghosted install.sh tests/test.sh examples/notify.sh.example
```

Requires Linux with GNU coreutils (it's a systemd-timer citizen anyway).

## License

MIT — see [LICENSE](LICENSE).
