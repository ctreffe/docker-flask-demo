"""A small Flask application for learning container configuration and deployment."""

import os

from flask import Flask, render_template


def create_app():
    """Create an app with fresh settings, so tests can supply their own environment."""
    application = Flask(__name__)

    # Environment variables let one image behave differently in each environment.
    # The default keeps the app usable even when GREETING_TEXT has not been set.
    application.config["GREETING_TEXT"] = os.environ.get(
        "GREETING_TEXT", "Hello from the Flask container!"
    )

    @application.get("/")
    def index():
        # Jinja escapes the greeting in the HTML template. Do not mark it as safe:
        # a configuration value should never become executable browser content.
        return render_template(
            "index.html", greeting=application.config["GREETING_TEXT"]
        )

    @application.get("/health")
    def health():
        # Docker checks this lightweight endpoint instead of guessing whether
        # a running process is also able to answer HTTP requests.
        return {"status": "ok"}, 200

    return application


# Gunicorn imports this variable through the command "app:app" in the Dockerfile.
app = create_app()

if __name__ == "__main__":
    # This server is only for local Python experiments. The container uses
    # Gunicorn instead, and neither server enables Flask's interactive debugger.
    app.run(host="127.0.0.1", port=5000, debug=False)
