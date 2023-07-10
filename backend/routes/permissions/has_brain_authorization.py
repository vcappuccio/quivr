from functools import wraps
from typing import Optional
from uuid import UUID

from auth.auth_bearer import get_current_user
from fastapi import HTTPException, status
from models.brains import Brain


def has_brain_authorization(required_role: str = "Owner"):
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            brain_id = UUID(kwargs.get("brain_id"))

            validate_brain_authorization(brain_id, required_role=required_role)

            return await func(*args, **kwargs)

        return wrapper

    return decorator


def validate_brain_authorization(
    brain_id: UUID,
    user_id: Optional[UUID] = None,
    required_role: Optional[str] = "Owner",
):
    user_id = user_id or get_current_user().id

    if not brain_id or not user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing brain ID or user ID",
        )

    brain = Brain(id=brain_id)
    user_brain = brain.get_brain_for_user(user_id)

    if user_brain is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="You don't have permission for this brain",
        )

    # TODO: Update this logic when we have more roles
    # Eg: Owner > Admin > User ... this should be taken into account
    if required_role and user_brain.get("rights") != required_role:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have the required role for this brain",
        )
