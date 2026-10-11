# Contributing

Keep the watchdog boring — that's the whole point.

## Ground rules

- **bash + POSIX-ish coreutils only.** No new runtime dependencies. New
  escalation behavior belongs behind config, not cleverness.
- **shellcheck-clean.** CI runs shellcheck on `bin/`, `install.sh`,
  `tests/test.sh`, and `examples/notify.sh.example`.
- **Test the ladder.** Any change to stage transitions needs a case in
  `tests/test.sh` (they're fast: fake mtimes, no systemd needed).
- The watchdog must remain **read-only** with respect to heartbeat paths.

## Dev loop

```sh
bash tests/test.sh
shellcheck bin/ghosted install.sh tests/test.sh examples/notify.sh.example
```

Small PRs, and say *why* in the description. Config-surface changes should
update `config/config.example` and the README table in the same commit.
