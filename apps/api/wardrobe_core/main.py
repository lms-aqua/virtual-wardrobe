"""FastAPI application factory.

Phase 2 exposes only health/readiness plus wired-up security middleware, CORS,
and structured logging. Auth, consent, scans, avatars, garments, and outfits
routers are added in Phase 3+ — each behind the ownership/authorization layer.
"""

from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI, Response, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from wardrobe_core import __version__
from wardrobe_core.config import get_settings
from wardrobe_core.db import get_engine
from wardrobe_core.logging import configure_logging, get_logger
from wardrobe_core.security_headers import SecurityHeadersMiddleware

log = get_logger("api")


@asynccontextmanager
async def lifespan(app: FastAPI):  # noqa: ANN201
    settings = get_settings()
    configure_logging(settings.log_level)
    log.info("api.startup", env=settings.wardrobe_env, version=__version__)
    # Dev/staging convenience: ensure tables exist. Production uses Alembic
    # migrations (see apps/api/migrations) and never auto-creates schema.
    if not settings.is_production:
        from wardrobe_core import models  # noqa: F401  (populate metadata)
        from wardrobe_core.db import Base, get_engine

        async with get_engine().begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    yield
    log.info("api.shutdown")


def create_app() -> FastAPI:
    settings = get_settings()

    # Hide interactive docs in production to reduce surface / info leakage.
    docs_url = None if settings.is_production else "/docs"
    redoc_url = None if settings.is_production else "/redoc"

    app = FastAPI(
        title="Virtual Wardrobe API",
        version=__version__,
        docs_url=docs_url,
        redoc_url=redoc_url,
        lifespan=lifespan,
    )

    from wardrobe_core.observability import RequestContextMiddleware

    app.add_middleware(RequestContextMiddleware)
    app.add_middleware(SecurityHeadersMiddleware, is_production=settings.is_production)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,  # session cookie
        allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "Idempotency-Key"],
        max_age=600,
    )

    from wardrobe_core.routers import (
        account,
        admin,
        auth,
        avatars,
        consents,
        garments,
        jobs,
        me,
        outfits,
        scans,
    )

    for router in (
        auth.router,
        me.router,
        consents.router,
        scans.router,
        avatars.router,
        garments.router,
        outfits.router,
        jobs.router,
        account.router,
        admin.router,
    ):
        app.include_router(router)

    @app.get("/health/live", tags=["health"])
    async def live() -> dict[str, str]:
        """Liveness: process is up. No external dependencies touched."""
        return {"status": "ok", "version": __version__}

    @app.get("/health/ready", tags=["health"])
    async def ready(response: Response) -> dict[str, object]:
        """Readiness: verify the database is reachable.

        Returns 503 when a dependency is down. This previously answered 200
        with a "degraded" body, which every orchestrator and load balancer
        reads as healthy — so an instance that had lost its database kept
        receiving traffic.
        """
        checks: dict[str, str] = {}
        healthy = True
        try:
            engine = get_engine()
            async with engine.connect() as conn:
                await conn.execute(text("SELECT 1"))
            checks["database"] = "ok"
        except Exception as exc:  # noqa: BLE001
            checks["database"] = "unavailable"
            healthy = False
            log.warning("readiness.db_failed", error=str(exc))

        if not healthy:
            response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {"status": "ok" if healthy else "degraded", "checks": checks}

    return app


app = create_app()
