from dataclasses import dataclass
import random
from random import randint
import math

# Struct for units and enemies
@dataclass
class Unit:
    id: int
    name: str
    index: int
    health: int
    attack: int
    defense: int
    speed: int
    level: int
    multiplier: float
    move_type: int
    target: int
    dealt: int

def advanceState(state: dict, seed: int, turn: int):
    """
    Takes the queries and applies them to the current stage enemy.
    """
    random.seed(seed + turn)
    enemy = state["enemies"][0]
    rng_move = randint(0, 2)    # Enemy move type
    # can also do damage validation here if we want
    for unit in state["units"]:
        calculatedDamage = 0
        unit.target = 0
        match unit.move_type:
            case 0: # Basic
                calculatedDamage = unit.attack * 0.3 # NOTE: change multipliers to something we agree on if necessary
            case 1: # Special
                calculatedDamage = unit.attack * 1.1 # TODO: change to actual unit special move multiplier value

        if rng_move == 2:
            enemy.health -= math.ceil(calculatedDamage * (1.0 - (min(enemy.defense, 9900) / 10000)))
            unit.dealt = math.ceil(calculatedDamage * (1.0 - (min(enemy.defense, 9900) / 10000)))
        else:
            enemy.health -= calculatedDamage
            unit.dealt = calculatedDamage

    if enemy.health <= 0:
        enemy.health = 0
        return
    enemy.move_type = rng_move
    if rng_move == 2: return

    rng_unit = randint(0, len(state["units"]) - 1) # choose a random unit
    enemy.target = rng_unit
    calculatedDamage = 0
    match rng_move:
        case 0: # Basic
            calculatedDamage = enemy.attack * 0.4
        case 1: # Special
            calculatedDamage = enemy.attack * 1.2

    if (state["units"][rng_unit].move_type == 2):   # if guarding, reduce damage
        state["units"][rng_unit].health -= math.ceil(calculatedDamage * (1.0 - (min(unit.defense, 9900) / 10000)))
        enemy.dealt = math.ceil(calculatedDamage * (1.0 - (min(unit.defense, 9900) / 10000)))
    else:
        state["units"][rng_unit].health -= calculatedDamage
        enemy.dealt = calculatedDamage