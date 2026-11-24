from sqlalchemy import ColumnElement, func, literal_column


def _vector(table: str) -> ColumnElement:
    return literal_column(f"{table}.search_vector")


def _query(q: str) -> ColumnElement:
    # websearch_to_tsquery eats any input without syntax errors
    return func.websearch_to_tsquery("german", q)


def matches(table: str, q: str) -> ColumnElement[bool]:
    return _vector(table).op("@@")(_query(q))


def rank(table: str, q: str) -> ColumnElement[float]:
    return func.ts_rank(_vector(table), _query(q))
