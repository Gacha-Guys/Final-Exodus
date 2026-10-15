"""Single-process local registration throttle; shared deployment needs shared storage."""
from collections import deque
from threading import Lock
import math
import time


class RegistrationLimiter:
    def __init__(self, limit=5, window_seconds=60, clock=time.monotonic):
        if limit < 1 or window_seconds < 1:
            raise ValueError('Rate-limit settings must be positive')
        self.limit, self.window, self.clock = limit, window_seconds, clock
        self.clients = {}
        self.lock = Lock()

    def retry_after(self, client):
        now = self.clock()
        with self.lock:
            # Expire idle clients to keep this local-demo store bounded in time.
            for key in list(self.clients):
                if self.clients[key][-1] <= now - self.window:
                    del self.clients[key]
            attempts = self.clients.setdefault(client, deque())
            while attempts and attempts[0] <= now - self.window:
                attempts.popleft()
            if len(attempts) >= self.limit:
                return max(1, math.ceil(attempts[0] + self.window - now))
            attempts.append(now)
            return 0
