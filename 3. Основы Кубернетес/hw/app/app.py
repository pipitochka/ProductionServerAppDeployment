import os
from http.server import BaseHTTPRequestHandler, HTTPServer

APP_MESSAGE = os.getenv("APP_MESSAGE", "Kubernetes lab")
APP_TOKEN = os.getenv("APP_TOKEN", "")


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self._respond(200, "ok\n")
        elif self.path == "/ready":
            if APP_TOKEN:
                self._respond(200, "ready\n")
            else:
                self._respond(503, "secret not configured\n")
        elif self.path == "/":
            token_status = "configured" if APP_TOKEN else "missing"
            body = (
                f"<h1>{APP_MESSAGE}</h1>"
                f"<p>Secret token: {token_status}</p>"
            )
            self._respond(200, body, "text/html; charset=utf-8")
        else:
            self._respond(404, "not found\n")

    def _respond(self, code, body, content_type="text/plain; charset=utf-8"):
        encoded = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, format, *args):
        return


def main():
    port = int(os.getenv("PORT", "8080"))
    server = HTTPServer(("0.0.0.0", port), Handler)
    print(f"Server running on http://0.0.0.0:{port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
