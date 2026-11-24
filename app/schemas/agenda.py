from datetime import date

from pydantic import BaseModel

from app.schemas.events import EventOut, Occurrence
from app.schemas.items import ItemOut
from app.schemas.projects import ProjectOut


class Agenda(BaseModel):
    start: date
    end: date
    events: list[Occurrence]
    due_todos: list[ItemOut]
    overdue_todos: list[ItemOut]


class SearchResults(BaseModel):
    items: list[ItemOut]
    projects: list[ProjectOut]
    events: list[EventOut]
