# Exo Community Configuration

Community-maintained Exo configuration for CachyOS + Niri.

## Install or update

From the repository directory:

```bash
bash install-exo-community.sh
```

The installer backs up the existing Ignis and Matugen configuration before updating it. It preserves:

- `~/.config/ignis/user_settings.json`
- generated `colors.scss` and `styles/preview-colors.scss`
- existing Matugen templates other than the Exo-owned `templates/colors.scss`
- all other Matugen configuration sections and templates

It enables Matugen wallpaper setting through `awww`, adds the Ignis Matugen template, adds Niri startup entries for Ignis and `awww-daemon`, and starts the daemon for the current session.

If the Niri config is not at `~/.config/niri/config.kdl`, add these entries manually to your active Niri config:

```kdl
spawn-at-startup "ignis" "init"
spawn-at-startup "awww-daemon"
```

## Workspace indicator styles

The workspace indicator supports Icons, Numbers, Dots, and Pills. Choose the style in Exo Settings under Interface / Extra Module Options.

## Notes

- The installer does not replace personal settings or generated colors.
- Backups are created beside the original configuration paths with a `.backup-TIMESTAMP` suffix.
- Restart Ignis or log out and back in after installing.
