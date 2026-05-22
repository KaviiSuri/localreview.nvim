# localreview.nvim

Annotate code with review comments directly in Neovim. Like GitHub PR reviews, but local, offline, and stored as JSON files alongside the code.

No external dependencies. Pure Lua + Neovim API.

## Features

- **Line & range annotations** -- annotate a single line or a visual selection
- **Floating window viewer** -- see all reviews on the current line with timestamps and git info
- **Virtual text hints** -- inline indicators showing review count per line
- **Staleness detection** -- reviews track the git commit they were created on and flag when HEAD moves
- **Navigation** -- jump between reviewed lines with `]r` / `[r` (wraps around)
- **Telescope integration** -- search all reviews across the project (optional, telescope not required)
- **Review mode** -- start a named review session, get buffer-local keymaps, and avoid global keybinding conflicts
- **Clipboard/headless export** -- export review comments in an agent-friendly format, with file paths, line numbers, code snippets, and optional session filtering
- **Path-scoped clearing** -- clear review files for a file or directory once everything is addressed, or just clear the active session
- **File-local storage** -- reviews stored as hidden JSON files next to the source, easy to gitignore or share

## Requirements

- Neovim >= 0.9
- Optional: [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for project-wide search

## Installation

### lazy.nvim

```lua
{
  "aneveux/localreview.nvim",
  config = function()
    require("localreview").setup()
  end,
}
```

### Other plugin managers

Clone or add this repo to your runtimepath, then call:

```lua
require("localreview").setup()
```

## Review mode & keybindings

Start review mode first:

```vim
:LocalReviewStart my-review
```

While review mode is active, LocalReview installs buffer-local keymaps on normal source buffers. This keeps which-key support intact while avoiding global conflicts with plugins like Octo.

| Key | Mode | Action |
|-----|------|--------|
| `<leader>ra` | n, v | Annotate current line or visual selection |
| `<leader>rv` | n | View reviews on current line |
| `<leader>rd` | n | Delete review on current line |
| `]r` | n | Jump to next review |
| `[r` | n | Jump to previous review |
| `<leader>rt` | n | Open Telescope review picker |
| `<leader>re` | n | Export review comments to clipboard |

Stop review mode with:

```vim
:LocalReviewStop
```

Check status with:

```vim
:LocalReviewStatus
```

To disable the review-mode keybindings entirely:

```lua
require("localreview").setup({ keys = false })
```

## Commands

| Command | Description |
|---------|-------------|
| `:LocalReviewStart [name]` | Start review mode. If `name` is omitted, a timestamp-based review name is generated |
| `:LocalReviewStop` | Stop review mode and remove LocalReview keymaps from buffers |
| `:LocalReviewStatus` | Show the active review session, if any |
| `:LocalReviewAnnotate` | Add review (supports `:'<,'>LocalReviewAnnotate` for ranges). Requires active review mode |
| `:LocalReviewView` | View reviews on current line |
| `:LocalReviewDelete` | Delete review on current line |
| `:LocalReviewNext` | Jump to next review |
| `:LocalReviewPrev` | Jump to previous review |
| `:LocalReviewTelescope` | Telescope picker (requires telescope.nvim) |
| `:LocalReviewExport [path]` | Export reviews for the active session within a file or directory. In UI mode, copies to clipboard; in headless mode, prints to stdout |
| `:LocalReviewExport! [path]` | Export all sessions for a file or directory |
| `:LocalReviewClear [path]` | Clear only the active session's stored review comments for a file or directory |
| `:LocalReviewClear! [path]` | Delete all stored review comments for a file or directory |

## Configuration

All options with defaults:

```lua
require("localreview").setup({
  keys = {
    annotate = "<leader>ra",
    view = "<leader>rv",
    delete = "<leader>rd",
    next_review = "]r",
    prev_review = "[r",
    telescope = "<leader>rt",
    export = "<leader>re",
  },
  virtual_text = {
    enabled = true,
    hl_group = "Comment",
    stale_hl_group = "LocalReviewStale",
  },
  git = {
    track_commit = true,
  },
})
```

## Telescope Extension

Load the extension after telescope:

```lua
require("telescope").load_extension("localreview")
```

Then use `:Telescope localreview` or the `<leader>rt` keybinding.

## Export & Clear

- `:LocalReviewExport` with no argument targets the current git repo root when available, otherwise the current working directory
- when review mode is active, export and clear default to the current named session
- add `!` to export or clear all sessions regardless of the active session
- `:LocalReviewExport path/to/file.ts` exports just that file's review comments
- `:LocalReviewExport path/to/dir` exports all review comments under that directory
- `:LocalReviewClear` follows the same targeting rules and removes the underlying `.reviews.json` files

In normal Neovim UI sessions, export copies the formatted review text to your clipboard. In headless mode, it prints to stdout, which makes it suitable for agent skills and shell scripts:

```sh
nvim --headless '+LocalReviewExport' +qa
nvim --headless '+LocalReviewClear' +qa
```

## Integrations

### Pi / coding agents

A bundled skill lives at [`skills/local-review/SKILL.md`](skills/local-review/SKILL.md). Copy or symlink it into your agent's skills directory so the agent knows how to read and clear local review comments.

### Claude Code

The [thorn](https://github.com/aneveux/claude-garden/tree/master/plugins/thorn) plugin for Claude Code can process and summarize `.reviews.json` files, letting you discuss review annotations with Claude directly in your terminal.

## Storage Format

Reviews are stored as hidden JSON files next to each source file. Each review entry may also include a `session_name`, allowing named review sessions to be resumed by starting review mode with the same name again:

```
foo.lua  ->  .foo.lua.reviews.json
```

To ignore review files in version control:

```gitignore
*.reviews.json
```

To share reviews with your team, commit them instead.

## Known Limitations

- **Line drift**: Reviews are stored by line number. Within a session, virtual text tracks edits (insertions/deletions above a review move the indicator). However, when you reopen the file, reviews appear at their **original stored line numbers** because the JSON file is not updated as lines shift. If you add 10 lines above a review, it will point at the wrong line on next open. This is a known trade-off for file-local, dependency-free storage.

## Development

```bash
# Install test dependency
make deps

# Run tests
make test

# Format code
make format
```

## License

MIT
