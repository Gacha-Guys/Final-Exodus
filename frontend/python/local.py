# Local mini server to connect Godot to unified battle engine module.

from fastapi import FastAPI
import uvicorn
from pydantic import BaseModel
from battleengine import Unit, advanceState

app = FastAPI(title="local")

class State(BaseModel):
    enemies: list[Unit]
    units: list[Unit]

class Data(BaseModel):
    seed: int
    turn: int

# Godot sends local state with move_types modified.
@app.post("/calculate")
def calculate(body: State, data: Data):
    local_state = {
        "units": body.units,
        "enemies": body.enemies
    }
    advanceState(local_state, data.seed, data.turn)
    return local_state

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=22567)
