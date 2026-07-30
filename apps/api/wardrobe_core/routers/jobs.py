"""Job status polling. A job is only visible to its owner."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from wardrobe_core.deps import get_current_user, get_db
from wardrobe_core.models import ScanJob, User
from wardrobe_core.schemas import JobOut

router = APIRouter(prefix="/jobs", tags=["jobs"])


@router.get("/{job_id}", response_model=JobOut)
async def get_job(
    job_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ScanJob:
    job = await db.get(ScanJob, job_id)
    if job is None or job.user_id != user.id:
        raise HTTPException(status_code=404, detail="not found")
    return job
