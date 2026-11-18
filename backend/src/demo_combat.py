"""One persistent encounter; no rewards or player-owned roster claims."""
import json
from uuid import UUID, uuid4
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from pydantic import Field, model_validator
from .demo_accounts import Body, authenticate
from .demo_tokens import authorization_header
from .demo_store import transaction

router = APIRouter()


class Start(Body):
    request_id: UUID


class Attack(Start):
    actor: Annotated[int, Field(strict=True, ge=0, le=2)]
    version: Annotated[int, Field(strict=True, ge=0)]


class Tap(Body):
    actor: Annotated[int, Field(strict=True, ge=0, le=2)]
    at_ms: Annotated[int, Field(strict=True, ge=0, le=900)]


class SquadRound(Start):
    version: Annotated[int, Field(strict=True, ge=0)]
    taps: Annotated[list[Tap], Field(min_length=1, max_length=3)]

    @model_validator(mode="after")
    def check_taps(self):
        times = [tap.at_ms for tap in self.taps]
        if times[0] != 0 or times != sorted(times):
            raise ValueError("Taps must start at zero and follow time order")
        if len({tap.actor for tap in self.taps}) != len(self.taps):
            raise ValueError("Each ally can act once per round")
        return self


WINDUP_MS = (300, 550, 150)
COMBO_WINDOW_MS = 120


def initial_state(battle_id):
    return {"id": battle_id, "version": 0, "status": "active", "turn": 1,
            "party": [{"name": name, "hp": 100, "max_hp": 100, "attack": attack}
                      for name, attack in [("Ember", 18), ("Rowan", 16), ("Vale", 14)]],
            "enemy": {"name": "Gate Sentinel", "hp": 100, "max_hp": 100, "attack": 8},
            "log": ["A sentinel blocks the gate. Choose a character to attack."]}


def advance(state, taps, *, squad):
    party, enemy = state["party"], state["enemy"]
    if state["status"] != "active" or any(party[tap.actor]["hp"] <= 0 for tap in taps):
        raise HTTPException(409, "That character cannot attack now")

    hits = []
    previous_impact = None
    for tap in sorted(taps, key=lambda tap: tap.at_ms + WINDUP_MS[tap.actor]):
        unit = party[tap.actor]
        impact = tap.at_ms + WINDUP_MS[tap.actor]
        combo = previous_impact is not None and impact - previous_impact <= COMBO_WINDOW_MS
        damage = unit["attack"] + (unit["attack"] // 2 if combo else 0)
        applied = min(enemy["hp"], damage)
        enemy["hp"] -= applied
        hits.append(dict(actor=tap.actor, at_ms=impact, damage=applied, hp=enemy["hp"], combo=combo))
        state["log"].append(f'{unit["name"]} deals {applied} damage.' + (" Combo!" if combo else ""))
        previous_impact = impact
        if enemy["hp"] == 0:
            break

    counter = None
    if enemy["hp"] == 0:
        state["status"] = "won"
        state["log"].append("Victory! The gate is clear. No rewards in this demo.")
    else:
        target = taps[0].actor
        unit = party[target]
        applied = min(unit["hp"], enemy["attack"])
        unit["hp"] -= applied
        counter = dict(actor=target, damage=applied, hp=unit["hp"])
        state["log"].append(f'The sentinel strikes {unit["name"]} for {applied}.')
        if all(member["hp"] == 0 for member in party):
            state["status"] = "lost"
    if squad:
        state["last_round"] = dict(taps=[tap.model_dump() for tap in taps], hits=hits, counter=counter)
    else:
        state.pop("last_round", None)
    state["version"] += 1
    state["turn"] += 1
    state["log"] = state["log"][-8:]
    return state


@router.post("/battles")
def start(body: Start, authorization: str | None = Depends(authorization_header)):
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
def current(authorization: str | None = Depends(authorization_header)):
    with transaction() as cursor:
        user_id = authenticate(cursor, authorization)
        cursor.execute("SELECT state FROM DemoBattles WHERE u_id=%s ORDER BY created_at DESC,id DESC LIMIT 1", (user_id,))
        existing = cursor.fetchone()
        return json.loads(existing["state"]) if existing else None


@router.post("/battles/{battle_id}/actions")
def attack(battle_id: UUID, body: Attack, authorization: str | None = Depends(authorization_header)):
    return save_action(battle_id, body, authorization)


@router.post("/battles/{battle_id}/rounds")
def squad_round(battle_id: UUID, body: SquadRound, authorization: str | None = Depends(authorization_header)):
    return save_action(battle_id, body, authorization)


def save_action(battle_id, body, authorization):
    squad = isinstance(body, SquadRound)
    taps = body.taps if squad else [Tap(actor=body.actor, at_ms=0)]
    actor = taps[0].actor
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
            saved = json.loads(retry["response"])
            saved_taps = saved.get("last_round", {}).get("taps")
            expected_taps = [tap.model_dump() for tap in taps] if squad else None
            if retry["actor"] != actor or retry["version"] != body.version or saved_taps != expected_taps:
                raise HTTPException(409, "Request ID already used for another action")
            return saved
        state = json.loads(existing["state"])
        if state["version"] != body.version:
            raise HTTPException(409, "Battle changed. Reload the saved battle")
        state = advance(state, taps, squad=squad)
        response = json.dumps(state)
        cursor.execute("UPDATE DemoBattles SET state=%s WHERE id=%s", (response, str(battle_id)))
        cursor.execute("INSERT INTO DemoActions(battle_id,request_id,actor,version,response) VALUES(%s,%s,%s,%s,%s)",
                       (str(battle_id), str(body.request_id), actor, body.version, response))
        return state
