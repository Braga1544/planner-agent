import json
from pathlib import Path

FIXTURES = Path(__file__).parent / "fixtures"


def fixture_fetcher(*names: str):
    # nth call -> nth file, then always the last one
    contents = [(FIXTURES / name).read_bytes() for name in names]
    calls: list[str] = []

    async def fetch(url: str) -> bytes:
        calls.append(url)
        return contents[min(len(calls), len(contents)) - 1]

    fetch.calls = calls
    return fetch


def parse_sse(body: str) -> list[tuple[str, dict]]:
    events = []
    for chunk in body.strip().split("\n\n"):
        lines = [line for line in chunk.splitlines() if not line.startswith(":")]  # sse comments
        if not lines:
            continue
        fields = dict(line.split(": ", 1) for line in lines)
        events.append((fields["event"], json.loads(fields["data"])))
    return events
