"""Security response headers applied to every API response.

These harden the API surface even though the primary UI is the web app. The web
app (Next.js) sets its own, stricter, page-level CSP; this covers direct API
responses, error pages, and the OpenAPI docs.
"""

from __future__ import annotations

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, *, is_production: bool) -> None:  # noqa: ANN001
        super().__init__(app)
        self._is_production = is_production

    async def dispatch(self, request: Request, call_next) -> Response:  # noqa: ANN001
        response = await call_next(request)
        headers = response.headers

        # API returns JSON; lock the document CSP down hard. Swagger UI needs a
        # relaxation, applied only on the docs paths.
        path = request.url.path
        if path.startswith(("/docs", "/redoc", "/openapi.json")):
            headers["Content-Security-Policy"] = (
                "default-src 'self'; img-src 'self' data:; "
                "script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'"
            )
        else:
            headers["Content-Security-Policy"] = (
                "default-src 'none'; frame-ancestors 'none'; base-uri 'none'"
            )

        headers["X-Content-Type-Options"] = "nosniff"
        headers["X-Frame-Options"] = "DENY"
        headers["Referrer-Policy"] = "no-referrer"
        headers["Cross-Origin-Opener-Policy"] = "same-origin"
        headers["Cross-Origin-Resource-Policy"] = "same-origin"
        headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"

        if self._is_production:
            headers["Strict-Transport-Security"] = (
                "max-age=63072000; includeSubDomains; preload"
            )

        return response
