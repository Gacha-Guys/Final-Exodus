"""Deterministic coverage of Mihai's banner and inventory prototype; no database."""
from collections import deque
from unittest.mock import Mock

import pytest

from src import Gacha


@pytest.mark.parametrize("draw,category,choices", [
    (1, "item", [(1, "Potion"), (2, "Boots")]),
    (90, "item", [(1, "Potion"), (2, "Boots")]),
    (91, "character", [(7, "Knight"), (8, "Mage")]),
    (100, "character", [(7, "Knight"), (8, "Mage")]),
])
def test_roll_keeps_90_10_boundary_and_uses_uniform_category_choice(monkeypatch, draw, category, choices):
    banner = Gacha.Unit_banner([(7, "Knight"), (8, "Mage")], [(1, "Potion"), (2, "Boots")],
                               [(90, "item"), (100, "character")])
    randint = Mock(return_value=draw)
    choice = Mock(side_effect=lambda entries: entries[-1])
    monkeypatch.setattr(Gacha.random, "randint", randint)
    monkeypatch.setattr(Gacha.random, "choice", choice)
    assert banner.roll() == [choices[-1], category]
    randint.assert_called_once_with(1, 100)
    choice.assert_called_once_with(choices)


@pytest.mark.parametrize("characters,items,message", [([], [(1, "Potion")], "No characters"),
                                                        ([(1, "Knight")], [], "No items")])
def test_empty_banner_pool_is_rejected(characters, items, message):
    with pytest.raises(ValueError, match=message):
        Gacha.Unit_banner(characters, items, [(90, "item"), (100, "character")])


def connection(rows=(), items=()):
    db = Mock()
    cursor = db.cursor.return_value
    cursor.fetchone.side_effect = deque(rows)
    cursor.fetchall.return_value = items
    return db, cursor


def test_build_banner_binds_ids_and_closes_cursor():
    db, cursor = connection([(7, "Knight")], [(1, "Potion"), (2, "Boots")])
    banner = Gacha.build_banner(db, 7, 5)
    assert banner.characters == [(7, "Knight")]
    assert banner.items == [(1, "Potion"), (2, "Boots")]
    assert banner.rates == [(90, "item"), (100, "character")]
    assert [call.args[1] for call in cursor.execute.call_args_list] == [(7,), (5,)]
    cursor.close.assert_called_once()
    db.commit.assert_not_called()


def test_build_banner_closes_cursor_when_query_fails():
    db, cursor = connection()
    cursor.execute.side_effect = RuntimeError("database unavailable")
    with pytest.raises(RuntimeError, match="database unavailable"):
        Gacha.build_banner(db, 1, 5)
    cursor.close.assert_called_once()


@pytest.mark.parametrize("result,existing,statement,args", [
    ([(7, "Knight"), "character"], None, "INSERT INTO C_owned", (42, 7)),
    ([(1, "Potion"), "item"], None, "INSERT INTO I_owned", (42, 1, 1)),
    ([(1, "Potion"), "item"], (3,), "UPDATE I_owned", (42, 1)),
])
def test_inventory_roll_preserves_character_or_item_award(result, existing, statement, args):
    db, cursor = connection([existing])
    Gacha.award_roll(db, 42, result)
    assert cursor.execute.call_args_list[0].args[1] == (42, result[0][0])
    assert cursor.execute.call_args_list[-1].args[0].startswith(statement)
    assert cursor.execute.call_args_list[-1].args[1] == args
    db.commit.assert_called_once()
    db.rollback.assert_not_called()
    cursor.close.assert_called_once()
    db.close.assert_not_called()  # The caller owns its connection.


def test_duplicate_character_is_not_awarded_twice():
    db, cursor = connection([(7,)])
    Gacha.award_roll(db, 42, [(7, "Knight"), "character"])
    assert cursor.execute.call_count == 1
    db.commit.assert_called_once()
    cursor.close.assert_called_once()


@pytest.mark.parametrize("failure", ["select", "write", "commit"])
def test_inventory_failure_rolls_back_and_closes_cursor(failure):
    db, cursor = connection([None])
    if failure == "select":
        cursor.execute.side_effect = RuntimeError("interrupted")
    elif failure == "write":
        cursor.execute.side_effect = [None, RuntimeError("interrupted")]
    else:
        db.commit.side_effect = RuntimeError("interrupted")
    with pytest.raises(RuntimeError, match="interrupted"):
        Gacha.award_roll(db, 42, [(1, "Potion"), "item"])
    db.rollback.assert_called_once()
    cursor.close.assert_called_once()
