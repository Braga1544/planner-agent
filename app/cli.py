import argparse
import asyncio
import uuid

from app.db import get_sessionmaker
from app.services import tokens


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="python -m app.cli", description="planner-agent admin")
    sub = parser.add_subparsers(dest="command", required=True)
    create = sub.add_parser("create-token", help="create a new device token")
    create.add_argument("name", help="e.g. iPhone or Web")
    sub.add_parser("list-tokens", help="list all tokens")
    revoke = sub.add_parser("revoke-token", help="revoke a token")
    revoke.add_argument("token_id")
    return parser


async def _run(args: argparse.Namespace) -> None:
    async with get_sessionmaker()() as session:
        if args.command == "create-token":
            token, raw = await tokens.create_token(session, args.name)
            print(f"token for '{token.name}' (id {token.id}), shown only once:\n{raw}")
        elif args.command == "list-tokens":
            for t in await tokens.list_tokens(session):
                state = "gesperrt" if t.revoked_at else "aktiv"
                print(f"{t.id}  {t.name:<20} {state:<9} last used: {t.last_used_at or '-'}")
        elif args.command == "revoke-token":
            t = await tokens.revoke_token(session, uuid.UUID(args.token_id))
            print(f"token '{t.name}' revoked")


def main(argv: list[str] | None = None) -> None:
    asyncio.run(_run(build_parser().parse_args(argv)))


if __name__ == "__main__":
    main()
