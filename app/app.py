"""A simple web app that counts how many times it has been viewed."""

import os

from flask import Flask
from redis import Redis

redis_host = os.environ.get("REDIS_HOST")
redis_port = os.environ.get("REDIS_PORT", 6379)

app = Flask(__name__)
redis = Redis(host=redis_host, port=redis_port)

@app.route('/')
def hello():
    """Return how many times this page has been viewed."""
    redis.incr('hits')
    counter = int(redis.get('hits'))
    return f"This webpage has been viewed {counter} time{'s' if counter != 1 else ''}"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)
