# Termnotes

A Mac notes app with a translucent, terminal-style editor and a GitHub README-style preview. Add tables, charts and images, define words in your own dictionary, and use two-letter shorthands. Names, dates and times are highlighted green, dictionary words blue. Light and dark mode.

## Download

**[Download Termnotes.zip](https://github.com/bradynoscarmclean/Notes/releases/latest/download/Termnotes.zip)**. Unzip it and drag **Termnotes** into Applications.

The first time you open it, macOS will block it because it isn't from the App Store. Go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**. You only need to do this once.

## Shortcuts

| Keys | Action |
| --- | --- |
| ⌘E | Switch between Write and Preview |
| ⌘T | Insert a table |
| ⌘⇧C | Insert a chart (bar, line, pie or flow) |
| ⌘⇧I | Insert an image (you can also paste or drag one in) |
| ⌘D | Define the selected word |
| ⌘S | Add a shorthand (2 letters → full word) |
| ⌘⇧S | Make a shorthand for the selected word |
| Tab | Expand the shorthand before the cursor |
| ⌘L | Show/hide your shorthands and dictionary |
| ⌘N | New note |
| ⌘⇧D | Delete note |
| ⌘P | Push the note to a GitHub repo as README.md (images go to images/) |
| ⌘G | Connect or disconnect your GitHub account |
| ⌘⇧L | Switch between light and dark mode |
| ⌘, | Settings |
| ⌘/ | Show all shortcuts |

Notes are written in Markdown, the same format GitHub READMEs use, so a pushed note looks the same on GitHub as in the Preview tab. Charts are [Mermaid](https://mermaid.js.org) code blocks, which GitHub also draws as charts.

Notes are saved in `~/Library/Application Support/Termnotes/store.json`, and images in the `images` folder next to it.

## Building

```sh
./build.sh
```

Outputs `build/Termnotes.app` and `build/Termnotes.zip`.
