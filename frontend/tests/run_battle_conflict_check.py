"""Run the Godot battle conflict regression against a disposable HTTP fixture."""
import argparse
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import shutil
import subprocess
import threading

FRONTEND = Path(__file__).resolve().parents[1]


class BattleFixture(BaseHTTPRequestHandler):
    def reply(self, status, body):
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        if self.path != "/battles/current":
            self.send_error(404)
            return
        self.server.requests_seen.append("reload")
        if self.server.requests_seen == ["reload", "round", "reload"]:
            self.reply(503, {"detail": "Temporary reload failure"})
            return
        version = int("round" in self.server.requests_seen)
        ally = {"name": "Ally", "hp": 100, "max_hp": 100, "attack": 18}
        self.reply(200, {
            "id": "fixture-battle", "version": version, "status": "active",
            "turn": version + 1, "party": [ally] * 3,
            "enemy": {**ally, "hp": 100 - 18 * version}, "log": [],
        })

    def do_POST(self):
        if self.path != "/battles/fixture-battle/rounds":
            self.send_error(404)
            return
        self.rfile.read(int(self.headers["Content-Length"]))
        self.server.requests_seen.append("round")
        self.reply(409, {"detail": "Battle changed"})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot", help="Godot executable or absolute path")
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if godot is None:
        parser.error("Godot executable not found. Pass its path with --godot.")
    with HTTPServer(("127.0.0.1", 0), BattleFixture) as server:
        server.requests_seen = []
        worker = threading.Thread(target=server.serve_forever)
        worker.start()
        try:
            env = {**os.environ, "FINAL_EXODUS_API_ORIGIN": f"http://127.0.0.1:{server.server_port}"}
            subprocess.run(
                [str(Path(godot).resolve()), "--headless", "--path", str(FRONTEND),
                 "--script", "res://tests/battle_conflict_check.gd"],
                check=True, shell=False, timeout=20, env=env,
            )
            if server.requests_seen != ["reload", "round", "reload", "reload"]:
                raise RuntimeError(f"Unexpected battle requests: {server.requests_seen}")
        finally:
            server.shutdown()
            worker.join()


if __name__ == "__main__":
    main()
