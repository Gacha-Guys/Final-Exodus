import random
from datetime import datetime
import os
from dotenv import load_dotenv
from database import connect

class Unit_banner:
    def __init__(self, characters, items, rates):
        if len(characters) == 0:
            raise ValueError("No characters")
        if len(items) == 0:
            raise ValueError("No items")
        self.characters = characters # Predefined lists of 2-3 characters. Once more are implemented, a "banner" would cycle to another list each day. Probably temporary implementation. List of id, name tuples
        self.items = items # Predefined list of items that can be obtained from a unit banner. This remains consistent. Probably temporary implementation. List of id, name tuples
        self.rates = rates

    def roll(self):
        rolled = random.randint(1, 100)

        rolledtype = None
        for entry in self.rates:
            if rolled <= entry[0]:
                rolledtype = entry[1]
                break

        if rolledtype == "character": #currently all characters and items have equal rates between one another. This WILL change.
            choice = random.choice(self.characters)
        else:
            choice = random.choice(self.items)

        result = [choice, rolledtype]
        return result


def build_banner(connection, character_id, max_item_id): #very temporary. Considering storing banners in the database in the future.
    cursor = connection.cursor()
    try:
        characters = []
        cursor.execute("SELECT id, name FROM Characters WHERE id = %s LIMIT 1",(character_id,)) #%s blocks sql injection but this would never fall into users hands so it's superfluous
        row = cursor.fetchone()
        if row is not None:
            characters.append((row[0], row[1]))

        cursor.execute("SELECT id, name FROM Items WHERE id <= %s", (max_item_id,))
        items = []
        for row in cursor.fetchall():
            items.append((row[0], row[1]))

    finally:
        cursor.close()

    rates = [(90, "item"), (100, "character")] #currently fixed rates. This WILL change and there will be more categories

    return Unit_banner(characters, items, rates)

if __name__ == "__main__": #temporary main since we don't have a runtime file
    env_path = os.path.join(os.path.dirname(__file__), "..", ".env")
    load_dotenv(env_path, override=True)

    connection = connect()
    try:
        banner = build_banner(connection, [1], 5)
    finally:
        connection.close()

    print("Characters on banner:", banner.characters)
    print("Items on banner:", banner.items)

    for pull_number in range(1, 11): #does 10 pulls
        result = banner.roll()
        print("rolled a " + result[0][1])
        connection = connect()
        try: #Entire block is EXTREMELY temporary, and it's only to show connection between our project and our database. In the future, I_owned will probably have triggers to initialize each user having 0 of each item at the start, so safety checks and inserts won't be necessary, and it will be a simple +1 to count
            cursor = connection.cursor()
            if result[1] == "character":

                cursor.execute("SELECT c_id FROM C_owned WHERE u_id = %s AND c_id = %s",(3, result[0][0]))
                existing = cursor.fetchone()

                if existing is None:
                    cursor.execute("INSERT INTO C_owned (u_id, c_id) VALUES (%s, %s)",(3, result[0][0]))
                    connection.commit()

                else:
                    print("Already owned, skipping")

            else:
                item_id = result[0][0]
                cursor.execute("SELECT count FROM I_owned WHERE u_id = %s AND i_id = %s", (3, item_id))
                existing = cursor.fetchone()

                if existing is None:
                    cursor.execute("INSERT INTO I_owned (u_id, i_id, count) VALUES (%s, %s, %s)",(3, item_id, 1))

                else:
                    cursor.execute("UPDATE I_owned SET count = count + 1 WHERE u_id = %s AND i_id = %s",(3, item_id))

                connection.commit()
        finally:
            connection.close()