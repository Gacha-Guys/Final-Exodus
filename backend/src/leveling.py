"""
Leveling System
Uses User and Unit struct
"""

from lib.struct import User
from enum import Enum

# The max possible level a user can have
MAX_USER_LEVEL   =   50
# The max possible level a unit can have
MAX_UNIT_LEVEL   =   100

# Defined units
class UnitXpGain(Enum):
    LOW = 100
    MED = 400
    HIGH = 1000

class UserXpGain(Enum):
    DAILY = 10
    QUEST = 50
    MISSION = 35

def levelUnit(u : Unit, x : UnitXpGain):
    if isinstance(x, UnitXpGain):
        u.experience += x.value
        updateLevel(u)
    else:
        print("Invalid XP modification!")

def levelUser(u : User, x : UserXpGain):
    if isinstance(x, UserXpGain):
        u.experience += x.value
        updateLevelUser(u)
    else:
        print("Invalid XP modification!")

def requiredExpUser(u : User):
    # Makes required experience look arbitrary
    return u.level ** 2 * 5

def requiredExp(u : Unit):
    return u.level ** 2 * 100

def updateLevelUser(u : User):
    if u.level >= MAX_USER_LEVEL: return
    # Check if user has enough xp to level up.
    while u.experience >= requiredExpUser(u):
        u.level += 1

def updateLevel(u : Unit):
    if u.level >= MAX_UNIT_LEVEL: return
    # Check if unit has enough xp to level up.
    while u.experience >= requiredExp(u):
        u.level += 1
