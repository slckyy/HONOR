from pathlib import Path
import re, sys
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
IGNORE_NAMES = {"package-lock.json", "HONOR_SECRET_ENV_REGISTRY.json", ".env.example"}
IGNORE_PATH_PARTS = {
    ".git",
    ".next",
    ".venv",
    "node_modules",
    "__pycache__",
}
BINARY_SUFFIXES = {".zip", ".png", ".jpg", ".jpeg", ".gif", ".mp4", ".pyc"}
PATTERNS = [
    ("private-key", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
    ("openai-key", re.compile(r"\bsk-[A-Za-z0-9_-]{20,}\b")),
    ("jwt", re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b")),
    ("postgres-password-url", re.compile(r"postgres(?:ql)?://[^\s\"\']+", re.I)),
]


def is_explicit_test_database_url(value: str) -> bool:
    """Allow only obviously local, non-production fixture credentials.

    The scanner still fails on any password-bearing Postgres URL whose host is not
    localhost/loopback, so weakening a test fixture into a live-looking secret is
    caught immediately.
    """
    try:
        parsed = urlsplit(value)
    except ValueError:
        return False
    if parsed.scheme not in {"postgres", "postgresql"}:
        return False
    if parsed.hostname not in {"localhost", "127.0.0.1", "::1", "postgres"}:
        return False
    allowed_pairs = {
        ("postgres", "postgres"),
        ("postgres", "dev-only-postgres"),
        ("x", "x"),
        ("u", "p"),
        ("honor_app", "dev-only-honor-app"),
        ("honor_app", "ci-honor-app-password"),
    }
    return (parsed.username or "", parsed.password or "") in allowed_pairs


def allowed_placeholder(name: str, value: str) -> bool:
    lowered = value.lower()
    if "replace_me" in lowered or "example" in lowered:
        return True
    if name == "postgres-password-url" and is_explicit_test_database_url(value):
        return True
    return False


issues = []
for path in ROOT.rglob("*"):
    if (
        not path.is_file()
        or any(part in IGNORE_PATH_PARTS for part in path.parts)
        or path.name in IGNORE_NAMES
        or path.suffix.lower() in BINARY_SUFFIXES
    ):
        continue
    try:
        text = path.read_text(errors="ignore")
    except OSError:
        continue
    for name, pattern in PATTERNS:
        for match in pattern.finditer(text):
            value = match.group(0).rstrip(",);]}")
            if allowed_placeholder(name, value):
                continue
            issues.append((str(path.relative_to(ROOT)), name, value[:80]))

if issues:
    for issue in issues:
        print("SECRET?", issue)
    sys.exit(1)
print("OK: no live-secret patterns detected")
