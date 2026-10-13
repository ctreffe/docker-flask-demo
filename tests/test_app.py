"""Behavior tests using Python's built-in unittest runner and Flask's test client."""

import os
import unittest
from unittest.mock import patch

from app import create_app


class AppTests(unittest.TestCase):
    def test_default_greeting(self):
        # clear=True isolates this test from settings on the developer's computer.
        with patch.dict(os.environ, {}, clear=True):
            client = create_app().test_client()
        response = client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertIn(b"Hello from the Flask container!", response.data)

    def test_configured_greeting_is_escaped(self):
        # A greeting may contain HTML characters. They must be shown as text,
        # not interpreted as an HTML element or a script supplied through config.
        with patch.dict(os.environ, {"GREETING_TEXT": "Hello <script>alert(1)</script>"}):
            client = create_app().test_client()
        response = client.get("/")
        self.assertIn(b"Hello &lt;script&gt;alert(1)&lt;/script&gt;", response.data)
        self.assertNotIn(b"<script>", response.data)

    def test_health_endpoint(self):
        response = create_app().test_client().get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json(), {"status": "ok"})


if __name__ == "__main__":
    unittest.main()
