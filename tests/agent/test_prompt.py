from datetime import datetime
from zoneinfo import ZoneInfo

from app.agent.prompt import SYSTEM_PROMPT, now_prefix


def test_system_prompt_lists_areas_and_is_static():
    for slug in ("work", "business", "hobby", "personal"):
        assert f"- {slug}" in SYSTEM_PROMPT
    assert "{" not in SYSTEM_PROMPT  # no placeholders -> stable cache prefix


def test_now_prefix():
    now = datetime(2026, 10, 9, 20, 11, tzinfo=ZoneInfo("Europe/Berlin"))
    assert now_prefix(now) == "[Jetzt: Fr, 09.10.2026 20:11 Europe/Berlin]"
