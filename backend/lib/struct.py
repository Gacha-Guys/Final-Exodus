"""
File holding all structs, i.e Unit, Item, User, etc.

MAY (WILL) CHANGE IN THE FUTURE.
"""

from dataclasses import dataclass
from datetime import datetime

@dataclass
class Unit:
    """
    Class representing a unit in the game.
    """
    id: int
    name: str
    health: int
    attack: int
    defense: int
    speed: int
    moves: list
    level: int
    experience: int

@dataclass
class Move:
    """
    Class representing a move in the game.
    """
    id: int
    name: str
    power: int
    accuracy: float
    type: str

@dataclass
class Item:
    """
    Class representing an item in the game.
    """
    id: int
    name: str
    description: str

@dataclass
class User:
    """
    Class representing a user in the game.
    """
    id: int
    username: str
    email: str
    level: int
    experience: int

@dataclass
class Session:
    """
    Class representing a session in the game.
    """
    token: str
    user: User
    start_time: datetime
    end_time: datetime
