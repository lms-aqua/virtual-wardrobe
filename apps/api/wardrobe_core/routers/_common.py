"""Shared router helpers — the ownership gate.

``owned_or_404`` is the single choke point for row-level authorization: if the
row is missing OR not owned by the requester, it returns 404 (never 403), so an
attacker cannot even confirm another user's resource exists.
"""

from __future__ import annotations

import uuid
from typing import TypeVar

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

T = TypeVar("T")


async def owned_or_404(
    db: AsyncSession, model: type[T], row_id: uuid.UUID, user_id: uuid.UUID
) -> T:
    row = await db.get(model, row_id)
    if row is None or getattr(row, "user_id", None) != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="not found")
    return row
