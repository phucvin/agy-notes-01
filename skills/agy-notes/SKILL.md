---
name: agy-notes
description: >-
  Save, update, and continuously push conversation notes or skills into the
  phucvin/agy-notes-01 GitHub repository. Use this skill whenever the user asks
  to save notes, push notes to agy-notes-01, keep pushing notes during a
  conversation, record findings/summaries to their notes repo, or archive a
  reusable skill in agy-notes-01.
---

# agy-notes

Push structured Markdown notes (and reusable skills) from any conversation into
[`phucvin/agy-notes-01`](https://github.com/phucvin/agy-notes-01).

- **Local clone:** `~/.gemini/antigravity-cli/scratch/agy-notes-01`
- **Remote:** `https://github.com/phucvin/agy-notes-01.git` (`main` branch)
- **Helper script:** [notes-git.sh](./scripts/notes-git.sh)

## Workflow

### 1. Sync the Repository First

Run the helper script to ensure the repo is cloned and up to date with `origin/main`:

```bash
bash ~/.gemini/config/skills/agy-notes/scripts/notes-git.sh sync
```

This prints the repo path and existing files in `notes/` so you can reuse an
existing note file instead of creating duplicates.

### 2. Write or Update the Note

- **Path:** `notes/<kebab-case-slug>.md` (e.g., `notes/writership.md`).
- **Updating existing notes:** If a note for the current topic already exists,
  update or append to it cleanly rather than creating a second file (unless the
  user asks for a separate note).
- **Formatting:**
  - Start with a clear `# <Title>` heading and brief context/metadata (links,
    date, or repo if relevant).
  - Use concise sections, bullet lists, and tables; distill raw discussion into
    durable takeaways.
  - **Never commit secrets, tokens, credentials, or sensitive local data.**

### 3. Update `README.md` Index

When adding a **new** note, add a bullet under `## Notes` in `README.md`
matching the existing format:

```markdown
- [`notes/<slug>.md`](notes/<slug>.md) — Short one-line summary.
```

When adding a **new** skill under `skills/<name>/`, add a bullet under
`## Skills` with its install command (`cp -r skills/<name> ~/.gemini/config/skills/`).
Do not duplicate entries when updating an existing note.

### 4. Commit, Push, and Verify

Stage and push only the files you touched:

```bash
bash ~/.gemini/config/skills/agy-notes/scripts/notes-git.sh push \
  "Add <Topic> notes" \
  notes/<slug>.md README.md
```

For follow-up updates to an existing note:

```bash
bash ~/.gemini/config/skills/agy-notes/scripts/notes-git.sh push \
  "Update <Topic> notes: <brief summary>" \
  notes/<slug>.md
```

The script stages only the listed paths, commits, rebases if `origin/main` moved
ahead, pushes without force, and prints the commit hash, `git status -sb`, and
GitHub links. Report the pushed file link and commit hash to the user.

## Continuous ("Keep Pushing") Mode

When the user asks to **keep pushing notes** throughout a conversation:

1. Pick (or confirm) a single target file `notes/<slug>.md` for the session.
2. Push an initial version as soon as there is substantive content.
3. On subsequent turns, whenever meaningful new findings, decisions, designs,
   fixes, or takeaways emerge, **proactively update `notes/<slug>.md` and push**
   at the end of the turn without waiting to be reminded.
4. Keep each commit message descriptive of what was added or changed, and mention
   the updated note briefly in your reply.
