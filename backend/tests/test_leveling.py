"""Jason's cumulative XP thresholds and both hard level caps."""
from typing import get_type_hints

import pytest

from lib.struct import Unit, User
from src import leveling


def user(level=1, xp=0):
    return User(1, "Tester", "tester@example.com", level, xp)


def unit(level=1, xp=0):
    return Unit(1, "Tester", 100, 10, 5, 10, [], level, xp, 1)


def test_unit_annotations_resolve_to_shared_struct():
    assert get_type_hints(leveling.levelUnit)["u"] is Unit
    assert get_type_hints(leveling.updateLevel)["u"] is Unit


@pytest.mark.parametrize("make,update,multiplier", [
    (user, leveling.updateLevelUser, 5),
    (unit, leveling.updateLevel, 100),
])
def test_threshold_is_inclusive_and_xp_remains_cumulative(make, update, multiplier):
    actor = make(2, 4 * multiplier - 1)
    update(actor)
    assert actor.level == 2
    actor.experience += 1
    update(actor)
    assert actor.level == 3
    assert actor.experience == 4 * multiplier


@pytest.mark.parametrize("make,grant,gain,cap,xp", [
    (user, leveling.levelUser, leveling.UserXpGain.DAILY, 50, 12490),
    (unit, leveling.levelUnit, leveling.UnitXpGain.HIGH, 100, 999000),
])
def test_one_award_cannot_cross_level_cap(make, grant, gain, cap, xp):
    actor = make(cap - 1, xp)
    grant(actor, gain)
    assert actor.level == cap
    assert actor.experience == xp + gain.value


@pytest.mark.parametrize("make,update,cap", [
    (user, leveling.updateLevelUser, 50),
    (unit, leveling.updateLevel, 100),
])
def test_large_cumulative_award_stops_at_cap(make, update, cap):
    actor = make(1, 10**12)
    update(actor)
    assert actor.level == cap
    update(actor)
    assert actor.level == cap


@pytest.mark.parametrize("make,grant,valid,invalid", [
    (user, leveling.levelUser, leveling.UserXpGain.MISSION, leveling.UnitXpGain.LOW),
    (unit, leveling.levelUnit, leveling.UnitXpGain.MED, leveling.UserXpGain.DAILY),
])
def test_only_matching_xp_enum_is_applied(make, grant, valid, invalid):
    actor = make()
    grant(actor, invalid)
    grant(actor, 100000)
    assert actor.level == 1 and actor.experience == 0
    grant(actor, valid)
    assert actor.experience == valid.value
