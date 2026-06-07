---
name: todo-progress-tracker
description: 'Persistent TODO/progress tracker committed in-repo for cross-machine continuity.'
argument-hint: 'Action + task details (list/add/update/show)'
---

# Todo Progress Tracker Skill

This skill stores and updates persistent TODO progress in:

`.github/skills/todo-progress-tracker/data/todos.json`

Because the data is committed in the repository, it can be pushed/pulled and reused across machines.

## Commands

```bash
python3 .github/skills/todo-progress-tracker/todo_progress.py init
python3 .github/skills/todo-progress-tracker/todo_progress.py list
python3 .github/skills/todo-progress-tracker/todo_progress.py show --id <task-id>
python3 .github/skills/todo-progress-tracker/todo_progress.py add --id <task-id> --title "<title>" --description "<description>" --status pending
python3 .github/skills/todo-progress-tracker/todo_progress.py update --id <task-id> --status in_progress
python3 .github/skills/todo-progress-tracker/todo_progress.py update --id <task-id> --notes "<notes>"
```

## Status Values

- `pending`
- `in_progress`
- `done`
- `blocked`

## Agent Behavior

When asked for current progress:
1. Run `list`.
2. If a task is referenced, run `show --id ...`.
3. Summarize done/in-progress/pending clearly.

When asked to update progress:
1. Update existing task if it exists.
2. Add new task if missing.
3. Keep descriptions concrete and outcome-focused.
