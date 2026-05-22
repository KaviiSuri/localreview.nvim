---
name: local-review
description: Use this skill when you need to read or clear localreview.nvim comments from a repository or file tree.
---

# Local Review

`localreview.nvim` stores review comments as hidden `.reviews.json` files next to source files.
These are user-authored review comments for the agent.

Run commands from the target repository root when working with a repo. For non-repo files,
run commands from a relevant parent directory. Assume the plugin is already installed in the
user's normal Neovim setup.

## Read comments

```sh
nvim --headless '+LocalReviewExport [path]' +qa
```

Omit `path` unless the user asks for a specific file or directory.

The export format includes:
- file paths
- line numbers or line ranges
- comment text
- a current code snippet
- stale markers when the review was left on an older commit

## Clear comments

```sh
nvim --headless '+LocalReviewClear [path]' +qa
```

Omit `path` unless the user asks for a specific file or directory.

## Usage

If the user invokes the skill without extra instructions, read the comments and proceed as if
this were a code review. Some comments may be questions, some may ask for concrete changes.

While responding to comments, tell the user which comment you are responding to. Prefer a
numbered list when there are only a few comments.

Comments can be stale. If they are marked stale, confirm with the user before addressing them.

Once all comments are addressed, ask the user whether they want the comments cleared.
Only clear them after explicit confirmation.
