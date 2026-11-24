from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse, Response
from fastapi.staticfiles import StaticFiles

# don't let the spa swallow these
_RESERVED = ("api", "calendar", "health", "docs", "redoc", "openapi.json")
_IMMUTABLE = "public, max-age=31536000, immutable"


class _ImmutableStaticFiles(StaticFiles):
    async def get_response(self, path, scope):
        response = await super().get_response(path, scope)
        if response.status_code == 200:
            response.headers["Cache-Control"] = _IMMUTABLE
        return response


def mount_spa(app: FastAPI, dist_dir: str) -> bool:
    # has to be the last route
    if not dist_dir:
        return False
    dist = Path(dist_dir).resolve()
    index = dist / "index.html"
    if not index.is_file():
        return False

    if (dist / "assets").is_dir():
        app.mount("/assets", _ImmutableStaticFiles(directory=dist / "assets"), name="spa-assets")

    @app.get("/{path:path}", include_in_schema=False)
    async def spa(path: str) -> Response:
        if path.split("/", 1)[0] in _RESERVED:
            return Response(status_code=404, content='{"detail":"Not Found"}',
                            media_type="application/json")
        candidate = (dist / path).resolve()
        if candidate.is_file() and candidate.is_relative_to(dist):
            return FileResponse(candidate)
        return FileResponse(index, headers={"Cache-Control": "no-cache"})

    return True
