from typing import Annotated
from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import Field, model_validator
from .account_routes import Body, authenticate
from .session_tokens import authorization_header
from .game_store import transaction

router = APIRouter()

@router.get("/db/character/{id}")
def getCharacter(id: int, authorization: str | None = Depends(authorization_header)):
    with transaction() as cursor:
        user_id = authenticate(cursor, authorization)
        cursor.execute("SELECT * FROM Characters WHERE id = %s;", id)
        return cursor.fetchone()
