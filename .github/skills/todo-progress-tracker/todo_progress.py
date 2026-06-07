#!/usr/bin/env python3
"""Persistent TODO tracker used by the Copilot CLI skill."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

VALID_STATUSES = {"pending", "in_progress", "done", "blocked"}


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def default_store_path() -> Path:
    return Path(__file__).resolve().parent / "data" / "todos.json"


def load_store(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"version": 1, "updatedAt": utc_now_iso(), "tasks": []}
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def save_store(path: Path, store: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    store["updatedAt"] = utc_now_iso()
    with path.open("w", encoding="utf-8") as handle:
        json.dump(store, handle, indent=2, sort_keys=True)
        handle.write("\n")


def find_task(store: dict[str, Any], task_id: str) -> dict[str, Any] | None:
    for task in store.get("tasks", []):
        if task.get("id") == task_id:
            return task
    return None


def cmd_init(path: Path) -> int:
    store = load_store(path)
    save_store(path, store)
    print(f"Initialized: {path}")
    return 0


def cmd_list(path: Path) -> int:
    store = load_store(path)
    tasks = store.get("tasks", [])
    if not tasks:
        print("No tasks found.")
        return 0
    print(f"{'ID':<36} {'STATUS':<12} TITLE")
    print("-" * 96)
    for task in tasks:
        print(
            f"{task.get('id', ''):<36} {task.get('status', 'pending'):<12} {task.get('title', '')}"
        )
    return 0


def cmd_show(path: Path, task_id: str) -> int:
    store = load_store(path)
    task = find_task(store, task_id)
    if task is None:
        print(f"Task not found: {task_id}")
        return 1
    print(json.dumps(task, indent=2, sort_keys=True))
    return 0


def cmd_add(
    path: Path,
    task_id: str,
    title: str,
    description: str,
    status: str,
    notes: str | None,
) -> int:
    store = load_store(path)
    if find_task(store, task_id) is not None:
        print(f"Task already exists: {task_id}")
        return 1
    now = utc_now_iso()
    store.setdefault("tasks", []).append(
        {
            "id": task_id,
            "title": title,
            "description": description,
            "status": status,
            "notes": notes,
            "createdAt": now,
            "updatedAt": now,
        }
    )
    save_store(path, store)
    print(f"Added: {task_id}")
    return 0


def cmd_update(
    path: Path,
    task_id: str,
    title: str | None,
    description: str | None,
    status: str | None,
    notes: str | None,
) -> int:
    store = load_store(path)
    task = find_task(store, task_id)
    if task is None:
        print(f"Task not found: {task_id}")
        return 1

    changed = False
    if title is not None:
        task["title"] = title
        changed = True
    if description is not None:
        task["description"] = description
        changed = True
    if status is not None:
        task["status"] = status
        changed = True
    if notes is not None:
        task["notes"] = notes
        changed = True

    if not changed:
        print("No changes requested.")
        return 1

    task["updatedAt"] = utc_now_iso()
    save_store(path, store)
    print(f"Updated: {task_id}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Persistent TODO tracker")
    parser.add_argument("--path", type=Path, default=default_store_path())
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("init")
    subparsers.add_parser("list")

    show_parser = subparsers.add_parser("show")
    show_parser.add_argument("--id", required=True)

    add_parser = subparsers.add_parser("add")
    add_parser.add_argument("--id", required=True)
    add_parser.add_argument("--title", required=True)
    add_parser.add_argument("--description", required=True)
    add_parser.add_argument("--status", default="pending", choices=sorted(VALID_STATUSES))
    add_parser.add_argument("--notes")

    update_parser = subparsers.add_parser("update")
    update_parser.add_argument("--id", required=True)
    update_parser.add_argument("--title")
    update_parser.add_argument("--description")
    update_parser.add_argument("--status", choices=sorted(VALID_STATUSES))
    update_parser.add_argument("--notes")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if args.command == "init":
        return cmd_init(args.path)
    if args.command == "list":
        return cmd_list(args.path)
    if args.command == "show":
        return cmd_show(args.path, args.id)
    if args.command == "add":
        return cmd_add(args.path, args.id, args.title, args.description, args.status, args.notes)
    if args.command == "update":
        return cmd_update(
            args.path,
            args.id,
            args.title,
            args.description,
            args.status,
            args.notes,
        )
    parser.print_help()
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
