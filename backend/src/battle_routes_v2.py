import json
from uuid import UUID, uuid4
from typing import Annotated
from dataclasses import asdict

from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import Field, model_validator
from .account_routes import Body, authenticate
from .session_tokens import authorization_header
from .game_store import transaction

from .battleengine import Unit, advanceState

import time
import hashlib


    

router = APIRouter()

# { <user id> : { "units/enemies" : <Unit> } }
_ongoing_battles: dict[int, dict[str, Unit]] = {}
# We need to store seeds for every battle to sync server and client battle engine rng
_seed: dict[int, int] = {}
# we also should store the turns
_turn: dict[int, int] = {}

# Initiate an ongoing battle for the user
class Start(Body):
    stage_id: int


# Move 0 = Basic
# Move 1 = Special
# Move 2 = Guard/Pass

class State(Body):
    enemies: list[Unit]
    units: list[Unit]


# { <stage id>, <enemy name>, <health>, <attack>, <defense>, <speed>, <multiplier> }
def getStage(s_id: int, cursor) -> dict:
    cursor.execute("SELECT * FROM enemy_stage_info WHERE stage_id = %s;", s_id)
    return cursor.fetchone()

def getParty(u_id: int, cursor) -> list:
    cursor.execute("SELECT * FROM battle_team_summary WHERE user_id = %s;", u_id)
    return cursor.fetchall()

# Create an ongoing battle for this user
@router.post("/battles/init")
def init(body: Start, authorization: str | None = Depends(authorization_header)):
    with transaction() as cursor:
        user_id = authenticate(cursor, authorization)
        _ongoing_battles[user_id] = {
            "units": [],
            "enemies": []
        }

        # load stage enemy info
        stage_info = getStage(body.stage_id, cursor)

        _ongoing_battles[user_id]["enemies"].append(
            Unit(
                id=-1,
                name=stage_info["name"],
                health=stage_info["health"],
                attack=stage_info["attack"],
                defense=stage_info["defense"],
                speed=stage_info["speed"],
                level=stage_info["level"],
                multiplier=stage_info["multiplier"],
                move_type=-1,
                index=0,
                target=-1,
                dealt=-1
                )
            )

        # load party info
        party_info = getParty(user_id, cursor)
        for i in range(len(party_info)):
            _ongoing_battles[user_id]["units"].append(
                Unit(
                    id=party_info[i]["c_id"],
                    name=party_info[i]["name"],
                    health=party_info[i]["health"],
                    attack=stage_info["attack"],
                    defense=party_info[i]["defense"],
                    speed=party_info[i]["speed"],
                    level=party_info[i]["level"],
                    multiplier=party_info[i]["multiplier"],
                    move_type=-1,
                    index=i,
                    target=-1,
                    dealt=-1
                    )
                )
        _seed[user_id] = str(time.time_ns())
        _turn[user_id] = 0
    return {"seed": _seed[user_id], "state": _ongoing_battles[user_id]}


def hashState(state: dict):
    normalized = json.dumps(normalize_numbers(state), sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(normalized.encode()).hexdigest()

def normalize_numbers(obj):
    if isinstance(obj, dict):
        return {k: normalize_numbers(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [normalize_numbers(v) for v in obj]
    elif isinstance(obj, int) and not isinstance(obj, bool):
        return float(obj)
    return obj

# client sends local state to server
@router.post("/battles/submit_turn")
def submit_turn(body: State, authorization: str | None = Depends(authorization_header)):
    with transaction() as cursor:
        user_id = authenticate(cursor, authorization)
        # set the move types on server equal to the client side
        for i in range(len(_ongoing_battles[user_id]["units"])):
            _ongoing_battles[user_id]["units"][i].move_type = body.units[i].move_type
        advanceState(_ongoing_battles[user_id], int(_seed[user_id]), _turn[user_id])
    server_state = {
        "units": [asdict(unit) for unit in _ongoing_battles[user_id]["units"]],
        "enemies": [asdict(enemy) for enemy in _ongoing_battles[user_id]["enemies"]]
    }

    if (hashState(server_state) == hashState(body.model_dump())):
        print("All is well!")
    else:
        print("Yeah blow this guy up.")
    _turn[user_id] += 1
    return {"turn": _turn[user_id], "state": _ongoing_battles[user_id]}

        

# TODO: make it so that when the client sends a request to initiate a battle, the server sends back a 
# random integer/id for a seed, so that both the client and the server and synced up in terms of rng aswell.
# the battleengine.py module can be used on both server and client. client needs to start a local python server
# that godot can access so the python module can be used.