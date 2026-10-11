# Security Policy

## ghosted is not a safety device

ghosted is a nudge with an escalation ladder. It has no availability or
correctness guarantees. Do **not** rely on it for medical alerts, welfare
checks on other people, or anything where a missed or false trigger has
serious consequences. Use a purpose-built service for that.

## Trust model

- Everything runs as **you**, at your privilege level. The watchdog only reads
  the paths you configure and writes inside `~/.ghosted`.
- `~/.ghosted/notify.sh` is **arbitrary code you chose to run** — treat it
  like a shell profile. If you wire it to email or push services, those
  credentials live on the same machine that may well be offline when the
  alert matters most.
- If you use an ntfy topic for delivery, the topic name **is** the secret:
  anyone who knows it can read (and post to) that topic. Pick something long
  and unguessable; don't reuse a cute name.
- Heartbeat paths leak a coarse signal ("something wrote here at time T") to
  anyone who can read them. That's inherent to the implicit-heartbeat design.

## Known limitations by design

- Machine off / powered down = watchdog off. No local software can fix this;
  see the README on external proof-of-life pings.
- Anyone with write access to your home directory can reset the switch
  (`touch ~/.ghosted/heartbeat`). It is a convenience signal, not a security
  boundary.

## Reporting vulnerabilities

Open a [private security advisory](https://github.com/Central-California-Health-Foundation/ghosted/security/advisories/new).
