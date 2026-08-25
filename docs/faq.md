# FAQ

## Home Assistant backup and restore

### What is included in a Home Assistant backup?

The add-on backup covers everything in `/data/iobroker` **except** the following directories, which are excluded because they are regenerable and would make the backup unnecessarily large:

| Excluded path | Reason |
|---|---|
| `iobroker/node_modules` | Restored automatically via `npm ci` on first start |
| `iobroker/backups` | ioBroker-native backups — back these up separately if needed |
| `iobroker/.cache` | npm cache, regenerated automatically |
| `iobroker/.npm` | npm cache, regenerated automatically |

The important data that **is** backed up includes the ioBroker database (`iobroker-data/`), all adapter configurations, `package.json`, `package-lock.json`, and `.npmrc`. This keeps the backup small (typically a few MB) while preserving the complete configuration.

### Why does ioBroker stop and start during a Home Assistant backup?

Whenever Home Assistant creates a backup that includes this add-on — a manual backup, an automatic backup schedule, or the backup taken before an add-on/core update — the js-controller is **stopped for the duration of the backup and started again afterwards**. The add-on log shows a normal shutdown followed by a normal start.

This is intentional. ioBroker keeps its states and objects database in memory and flushes it to disk periodically. If Home Assistant zipped `/data/iobroker` while the controller was running, it could capture a half-written database file or a set of files that do not belong to the same point in time — the resulting backup would be inconsistent and might not restore cleanly. Stopping the controller first guarantees that everything on disk is flushed and quiesced, so Home Assistant archives a clean, consistent snapshot.

The stop/start is driven by the `backup_pre` and `backup_post` hooks in [config.yaml](../iobroker/config.yaml), which call `/opt/scripts/maintenance.sh on` / `off`. The same mechanism is described in [Maintenance & Manual Operations](maintenance.md).

Practical consequences:

- ioBroker is unavailable for the duration of the backup — usually a few seconds to a minute, since `node_modules` and the other regenerable directories are excluded (see above). Adapters reconnect on their own once the controller is back.
- Schedule automatic backups at a time when a short interruption does not matter (e.g. at night).
- Nothing needs to be done manually. If the add-on should ever remain stopped after a backup, run `/opt/scripts/maintenance.sh off` in a container shell or restart the add-on from the Home Assistant UI.

### Restoring a backup on a new system

After a restore, `node_modules` will be absent. On the first start after the restore the add-on automatically runs `npm ci` to reinstall all packages at the exact same versions recorded in `package-lock.json`. This may take several minutes depending on the number of installed adapters and network speed. Progress is logged to `iobroker/log/npm_ci_restore.log`.

### Known issue: restore fails with "Not a gzipped file"

Restoring a large addon backup that contains hard links (such as those created by npm in `node_modules`) can fail with:

```
Not a gzipped file (b'\x94\xde')
```

This is a [known Supervisor bug](https://github.com/home-assistant/supervisor/issues/5891): Python's `tarfile` attempts to seek backwards in the gzip stream to resolve hard links, which fails when the stream is read as a non-seekable sub-stream from the outer backup tar.

The `backup_exclude` entries for `node_modules` introduced in version 0.0.24 eliminate this failure entirely by removing the hard-link-containing directories from the backup.

---

## Restoring backups of existing installation

When restoring a `iobroker.backitup` backup via a cloud storage provider (Dropbox, OneDrive, etc.) you may see:

```
TAR_BAD_ARCHIVE: Unrecognized archive format
```

The root cause is that `iobroker.backitup` downloads the backup file through the cloud provider's API and the resulting stream is not a valid tar archive — typically because the download returns an error page or a partially transferred file instead of the actual backup.

**Restoring a backup that is placed directly in the local filesystem (e.g. via manual upload in backitup) works fine.**
