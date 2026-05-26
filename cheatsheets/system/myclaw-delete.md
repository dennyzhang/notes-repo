# Delete a MyClaw Instance

## Steps

1. **List instances** to identify target:
   ```bash
   myclaw instances
   ```

2. **Gracefully stop** the instance (do NOT `kill` the PID — it respawns):
   ```bash
   # Named instance
   myclaw stop --instance <name>

   # Default instance
   myclaw stop
   ```

3. **Destroy** the instance (removes systemd service, registry entry, and home dir):
   ```bash
   myclaw destroy <name>
   ```
   If the instance is the default (`~/.myclaw`), `myclaw destroy` refuses. Do it manually:
   ```bash
   myclaw service uninstall
   rm -rf ~/.myclaw
   # Remove entry from ~/.myclaw-registry.json
   ```

4. **Verify** removal:
   ```bash
   myclaw instances
   ```

5. **Check other devservers** — the same GChat space may have a MyClaw instance running on a different host. If the bot still responds in GChat after local cleanup, SSH to other hosts and repeat.

## Key files

| File | Purpose |
|------|---------|
| `~/.myclaw-registry.json` | Instance registry (all instances) |
| `~/.myclaw/` | Default instance home dir |
| `~/.myclaw-<name>/` | Named instance home dir |
| `~/.config/systemd/user/myclaw-myclaw-<name>.service` | Systemd unit file |

## Gotchas

- **Never `kill` the PID directly** — a supervisor respawns it. Always use `myclaw stop`.
- **Default instance can't be `myclaw destroy`ed** — manual cleanup required (step 3 fallback).
- **GChat space stays active** until all hosts running that instance are cleaned up.
