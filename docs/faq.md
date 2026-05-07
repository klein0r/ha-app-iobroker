# FAQ

## Restoring backups of existing installation

When restoring a `iobroker.backitup` backup via a cloud storage provider (Dropbox, OneDrive, etc.) you may see:

```
TAR_BAD_ARCHIVE: Unrecognized archive format
```

The root cause is that `iobroker.backitup` downloads the backup file through the cloud provider's API and the resulting stream is not a valid tar archive — typically because the download returns an error page or a partially transferred file instead of the actual backup.

**Restoring a backup that is placed directly in the local filesystem (e.g. via manual upload in backitup) works fine.**
