from typing import Literal

from pydantic import BaseModel, ConfigDict

AreaSlug = Literal["work", "business", "hobby", "personal"]


class InputModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)
