"""One persistent encounter; no rewards or player-owned roster claims."""
import json
from uuid import UUID, uuid4
from typing import Annotated

from fastapi import APIRouter, Header, HTTPException
from pydantic import Field
from .demo_accounts import Body, authenticate
from .demo_store import transaction

router = APIRouter()


class Start(Body):
    request_id: UUID


class Attack(Start):
    actor: Annotated[int, Field(strict=True, ge=0, le=2)]
    version: Annotated[int, Field(strict=True, ge=0)]


def initial_state(battle_id):
    return {"id": battle_id, "version": 0, "status": "active", "turn": 1,
            "party": [{"name": name, "hp": 100, "max_hp": 100, "attack": attack}
                      for name, attack in [("Ember", 18), ("Rowan", 16), ("Vale", 14)]],
            "enemy": {"name": "Gate Sentinel", "hp": 100, "max_hp": 100, "attack": 8},
            "log": ["A sentinel blocks the gate. Choose a character to attack."]}


def advance(state, actor):
    unit, enemy = state["party"][actor], state["enemy"]
    if state["status"] != "active" or unit["hp"] <= 0:
        raise HTTPException(409, "That character cannot attack now")
    enemy["hp"] = max(0, enemy["hp"] - unit["attack"])
    state["log"].append(f'{unit["name"]} deals {unit["attack"]} damage.')
    if enemy["hp"] == 0:
        state["status"] = "won"
        state["log"].append("Victory! The gate is clear. No rewards in this demo.")
    else:
        unit["hp"] = max(0, unit["hp"] - enemy["attack"])
        state["log"].append(f'The sentinel strikes {unit["name"]} for {enemy["attack"]}.')
        if all(member["hp"] == 0 for member in state["party"]):
            state["status"] = "lost"
    state["version"] += 1
    state["turn"] += 1
    state["log"] = state["log"][-8:]
    return state


@router.post("/battles")
def start(body: Start, authorization: str | None = Header(default=None)):
    with transaction() as cursor:
        user_id = authenticate(cursor, authorization)
        cursor.execute("SELECT id FROM Users WHERE id=%s FOR UPDATE", (user_id,))
        cursor.execute("SELECT state FROM DemoBattles WHERE u_id=%s AND request_id=%s FOR UPDATE", (user_id, str(body.request_id)))
        existing = cursor.fetchone()
        if existing:
            return json.loads(existing["state"])
        cursor.execute("SELECT state FROM DemoBattles WHERE u_id=%s AND JSON_UNQUOTE(JSON_EXTRACT(state,'$.status'))='active' LIMIT 1 FOR UPDATE", (user_id,))
        existing = cursor.fetchone()
        if existing:
            return json.loads(existing["state"])
        state = initial_state(str(uuid4()))
        cursor.execute("INSERT INTO DemoBattles(id,u_id,request_id,state) VALUES(%s,%s,%s,%s)",
                       (state["id"], user_id, str(body.request_id), json.dumps(state)))
        return state


@router.get("/battles/current")
def current(authorization: str | None = Header(default=None)):
    with transaction() as cursor:
        user_id = authenticate(cursor, authorization)
        cursor.execute("SELECT state FROM DemoBattles WHERE u_id=%s ORDER BY created_at DESC,id DESC LIMIT 1", (user_id,))
        existing = cursor.fetchone()
        return json.loads(existing["state"]) if existing else None


@router.post("/battles/{battle_id}/actions")
def attack(battle_id: UUID, body: Attack, authorization: str | None = Header(default=None)):
    with transaction() as cursor:
        user_id = authenticate(cursor, authorization)
        cursor.execute("SELECT state FROM DemoBattles WHERE id=%s AND u_id=%s FOR UPDATE", (str(battle_id), user_id))
        existing = cursor.fetchone()
        if not existing:
            raise HTTPException(404, "Battle not found")
        cursor.execute("SELECT actor,version,response FROM DemoActions WHERE battle_id=%s AND request_id=%s FOR UPDATE",
                       (str(battle_id), str(body.request_id)))
        retry = cursor.fetchone()
        if retry:
            if retry["actor"] != body.actor or retry["version"] != body.version:
                raise HTTPException(409, "Request ID already used for another action")
            return json.loads(retry["response"])
        state = json.loads(existing["state"])
        if state["version"] != body.version:
            raise HTTPException(409, "Battle changed. Reload the saved battle")
        state = advance(state, body.actor)
        response = json.dumps(state)
        cursor.execute("UPDATE DemoBattles SET state=%s WHERE id=%s", (response, str(battle_id)))
        cursor.execute("INSERT INTO DemoActions(battle_id,request_id,actor,version,response) VALUES(%s,%s,%s,%s,%s)",
                       (str(battle_id), str(body.request_id), body.actor, body.version, response))
        return state
