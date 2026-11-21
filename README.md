# Termnotes

A simple Mac notes app with a clean dark editor, two-letter shorthands, and your own dictionary. Names and dates are highlighted yellow, dictionary words blue.

## Download

**[Download Termnotes.zip](https://github.com/bradynoscarmclean/Notes/releases/latest/download/Termnotes.zip)**. Unzip it and drag **Termnotes** into Applications.

The first time you open it, macOS will block it because it isn't from the App Store. Go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**. You only need to do this once.

## Shortcuts

| Keys | Action |
| --- | --- |
| ⌘D | Define the selected word (shows in blue; put the cursor on it to see the definition) |
| ⌥S | Add a shorthand (2 letters → full word) |
| Tab | Expand the shorthand before the cursor |
| ⌥L | Show/hide your shorthands and dictionary |
| ⌥N | New note |
| ⌥D | Delete note |
| ⌥P | Push the current note to a GitHub repo as README.md |
| ⌥G | Set or forget your GitHub token |

Notes are saved in `~/Library/Application Support/Termnotes/store.json`.

## Building

```sh
./build.sh
```

Outputs `build/Termnotes.app` and `build/Termnotes.zip`.
