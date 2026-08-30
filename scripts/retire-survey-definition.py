#!/usr/bin/env python
"""Archive and delete one survey definition, so schema rollback can proceed (AR-005).

Old code cannot parse the six answer kinds this change added.  That makes §14's
L2 *code* rollback unsafe while a definition using one still exists, and L3's
*schema* downgrade refuses outright.  This is the deliberate way out: it writes
everything to a JSON archive first, then deletes the rows, then records that it
did so in ``survey_definition_retirements``.

It is one-way.  There is no un-retire, because re-inserting clinical records
from a file is a decision an operator should make explicitly with the archive in
hand, not something a script should do on their behalf.

    python scripts/retire-survey-definition.py \\
        --database-port 5432 --database-name treehouse \\
        --definition <uuid> --archive-dir ./archives

``--dry-run`` reports what would go without touching anything.
"""

from __future__ import annotations

import argparse
import json
import sys
import uuid
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from sqlalchemy import create_engine, text
from sqlalchemy.engine import Connection

from app.config import AppConfig, build_database_dsn

#: Read in dependency order so the archive can be read back top-down.
_DEFINITION = text(
    "SELECT id, purpose, title, created_by, created_at "
    "FROM survey_definitions WHERE id = :definition"
)
_QUESTIONS = text(
    "SELECT id, ordinal, prompt, kind, min_value, max_value, allowed_values "
    "FROM survey_questions WHERE definition_id = :definition ORDER BY ordinal"
)
_SURVEYS = text(
    "SELECT id, user_id, taken_at FROM surveys WHERE definition_id = :definition ORDER BY taken_at"
)
_ANSWERS = text(
    "SELECT a.id, a.survey_id, a.question_id, a.note_text, a.numeric_value, "
    "a.range_value, a.transcript FROM survey_answers a "
    "JOIN surveys s ON s.id = a.survey_id WHERE s.definition_id = :definition"
)


def _rows(connection: Connection, statement: Any, definition: uuid.UUID) -> list[dict[str, Any]]:
    result = connection.execute(statement, {"definition": definition})
    return [
        {key: _plain(value) for key, value in row.items()}
        for row in (dict(zip(result.keys(), r, strict=True)) for r in result.fetchall())
    ]


def _plain(value: Any) -> Any:
    """JSON-safe, and lossless for the types this schema actually holds."""
    if isinstance(value, uuid.UUID | datetime):
        return str(value)
    if hasattr(value, "as_tuple"):  # Decimal: as text, so no scale is lost
        return str(value)
    return value


def archive_definition(
    connection: Connection, definition_id: uuid.UUID, archive_dir: Path
) -> dict[str, Any]:
    """Read everything that would be destroyed, and write it out first."""
    definition = _rows(connection, _DEFINITION, definition_id)
    if not definition:
        raise SystemExit(f"no such definition: {definition_id}")
    payload = {
        "archived_at": datetime.now(UTC).isoformat(),
        "definition": definition[0],
        "questions": _rows(connection, _QUESTIONS, definition_id),
        "surveys": _rows(connection, _SURVEYS, definition_id),
        "answers": _rows(connection, _ANSWERS, definition_id),
    }
    archive_dir.mkdir(parents=True, exist_ok=True)
    path = archive_dir / f"survey-definition-{definition_id}.json"
    path.write_text(json.dumps(payload, indent=2, sort_keys=True))
    payload["archive_path"] = str(path)
    return payload


def delete_definition(connection: Connection, definition_id: uuid.UUID) -> None:
    """Delete in FK order.  ``survey_questions`` cascades from the definition."""
    params = {"definition": definition_id}
    connection.execute(
        text(
            "DELETE FROM survey_answers WHERE survey_id IN "
            "(SELECT id FROM surveys WHERE definition_id = :definition)"
        ),
        params,
    )
    connection.execute(
        text(
            "DELETE FROM survey_answer_proposals WHERE question_id IN "
            "(SELECT id FROM survey_questions WHERE definition_id = :definition)"
        ),
        params,
    )
    connection.execute(text("DELETE FROM surveys WHERE definition_id = :definition"), params)
    connection.execute(
        text("DELETE FROM survey_questions WHERE definition_id = :definition"), params
    )
    connection.execute(text("DELETE FROM survey_definitions WHERE id = :definition"), params)


def retire(config: AppConfig, definition_id: uuid.UUID, archive_dir: Path, *, dry_run: bool) -> int:
    engine = create_engine(build_database_dsn(config))
    try:
        with engine.begin() as connection:
            payload = archive_definition(connection, definition_id, archive_dir)
            counts = (len(payload["surveys"]), len(payload["answers"]))  # type: ignore[arg-type]
            print(
                f"archived {payload['archive_path']}\n"
                f"  definition: {payload['definition']['title']!r}\n"  # type: ignore[index]
                f"  surveys:    {counts[0]}\n"
                f"  answers:    {counts[1]}"
            )
            if dry_run:
                # The archive is still written: seeing the file is the point of
                # a dry run.  Nothing is deleted.
                print("dry run: nothing deleted")
                connection.rollback()
                return 0
            delete_definition(connection, definition_id)
            connection.execute(
                text(
                    "INSERT INTO survey_definition_retirements "
                    "(id, definition_id, purpose, title, archive_path, surveys_archived, "
                    " answers_archived, retired_at) "
                    "VALUES (:id, :definition, :purpose, :title, :path, :surveys, :answers, :at)"
                ),
                {
                    "id": uuid.uuid4(),
                    "definition": definition_id,
                    "purpose": payload["definition"]["purpose"],  # type: ignore[index]
                    "title": payload["definition"]["title"],  # type: ignore[index]
                    "path": payload["archive_path"],
                    "surveys": counts[0],
                    "answers": counts[1],
                    "at": datetime.now(UTC),
                },
            )
        print("retired; schema downgrade may now proceed for this definition")
        return 0
    finally:
        engine.dispose()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--definition", required=True, help="survey definition uuid")
    parser.add_argument("--database-port", type=int, required=True)
    parser.add_argument("--database-name", required=True)
    parser.add_argument("--database-user")
    parser.add_argument("--database-password")
    parser.add_argument("--archive-dir", default="./archives", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    config = AppConfig(
        database_port=args.database_port,
        database_name=args.database_name,
        database_user=args.database_user,
        database_password=args.database_password,
    )
    return retire(config, uuid.UUID(args.definition), args.archive_dir, dry_run=args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
