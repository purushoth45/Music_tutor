from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import UserSettings, User
from app.schemas import UserSettingsResponse, UserSettingsUpdate

router = APIRouter(prefix="/settings", tags=["Settings"])

@router.get("", response_model=UserSettingsResponse)
def get_user_settings(
    user_id: int = Query(1, description="User ID for settings"),
    db: Session = Depends(get_db)
):
    """Retrieve user settings and preferences."""
    settings = db.query(UserSettings).filter(UserSettings.user_id == user_id).first()
    if not settings:
        settings = UserSettings(user_id=user_id)
        db.add(settings)
        db.commit()
        db.refresh(settings)
    return settings

@router.put("", response_model=UserSettingsResponse)
def update_user_settings(
    update_data: UserSettingsUpdate,
    user_id: int = Query(1, description="User ID for settings update"),
    db: Session = Depends(get_db)
):
    """Update user settings dynamically (Theme Mode, Accent Palette, Metronome, Audio Gain, Latency Profile)."""
    settings = db.query(UserSettings).filter(UserSettings.user_id == user_id).first()
    if not settings:
        settings = UserSettings(user_id=user_id)
        db.add(settings)

    update_dict = update_data.model_dump(exclude_unset=True)
    for field, value in update_dict.items():
        if value is not None:
            setattr(settings, field, value)

    db.commit()
    db.refresh(settings)
    return settings
