"""Harbor Goods catalog API: a small HTTP service on the Python standard library.

GET /health    -> 200 {"status": "ok"}, for the container and load balancer health checks
GET /products  -> 200 [...], the product list from products.json
Anything else  -> 404
"""

import json
import os
import signal
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

PRODUCTS = json.loads((Path(__file__).parent / "products.json").read_text())


class Handler(BaseHTTPRequestHandler):
    server_version = "harbor-catalog"

    def do_GET(self) -> None:
        if self.path == "/health":
            self.reply(200, {"status": "ok"})
        elif self.path == "/products":
            self.reply(200, PRODUCTS)
        else:
            self.reply(404, {"error": "not found"})

    def reply(self, status: int, body: object) -> None:
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format: str, *args: object) -> None:
        # One JSON line per request on stdout, which the awslogs driver ships to CloudWatch Logs.
        print(json.dumps({"client": self.client_address[0], "request": format % args}), flush=True)


def main() -> None:
    port = int(os.environ.get("PORT", "8080"))
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)  # noqa: S104 - a container must listen on all interfaces
    # ECS sends SIGTERM before it stops a task: finish cleanly instead of being killed.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    print(json.dumps({"message": "listening", "port": port}), flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
