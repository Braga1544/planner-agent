from app.config import Settings


def test_postgres_urls_are_converted_to_asyncpg():
    s = Settings(_env_file=None, database_url="postgres://u:p@db:5432/x")
    assert s.database_url == "postgresql+asyncpg://u:p@db:5432/x"
    s = Settings(_env_file=None, database_url="postgresql://u:p@db:5432/x")
    assert s.database_url == "postgresql+asyncpg://u:p@db:5432/x"


def test_cors_origin_list_and_timezone():
    s = Settings(_env_file=None, cors_origins="http://a.local, http://b.local", timezone="Europe/Berlin")
    assert s.cors_origin_list == ["http://a.local", "http://b.local"]
    assert s.tz.key == "Europe/Berlin"
    assert Settings(_env_file=None).cors_origin_list == []
