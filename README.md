# Termnotes

A simple Mac notes app with a translucent, terminal-style look, two-letter shorthands, and your own dictionary. Names, dates and times are highlighted green, dictionary words blue. Light and dark mode.

## Download

**[Download Termnotes.zip](https://github.com/bradynoscarmclean/Notes/releases/latest/download/Termnotes.zip)**. Unzip it and drag **Termnotes** into Applications.

The first time you open it, macOS will block it because it isn't from the App Store. Go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**. You only need to do this once.

## Shortcuts

| Keys | Action |
| --- | --- |
| ⌘D | Define the selected word (shows in blue; put the cursor on it to see the definition) |
| ⌘S | Add a shorthand (2 letters → full word) |
| ⌘⇧S | Make a shorthand for the selected word |
| Tab | Expand the shorthand before the cursor |
| ⌘L | Show/hide your shorthands and dictionary |
| ⌘N | New note |
| ⌘⇧D | Delete note |
| ⌘P | Push the current note to a GitHub repo as README.md |
| ⌘G | Connect or disconnect your GitHub account |
| ⌘⇧L | Switch between light and dark mode |
| ⌘, | Settings (auto-expand shorthands, highlighting, text size, theme) |

Notes are saved in `~/Library/Application Support/Termnotes/store.json`.

## Building

```sh
./build.sh
```

Outputs `build/Termnotes.app` and `build/Termnotes.zip`.
