#!/usr/bin/env python
"""Django's command-line utility for administrative tasks."""
import os
import socket
import subprocess
import sys
from pathlib import Path


NON_DB_COMMANDS = {
    "--help",
    "--version",
    "-h",
    "compilemessages",
    "diffsettings",
    "help",
    "makemessages",
    "makemigrations",
    "startapp",
    "startproject",
    "version",
}


def load_local_env(project_root: Path) -> None:
    env_path = project_root / ".env"
    if not env_path.exists():
        return

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if not key:
            continue
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
            value = value[1:-1]
        os.environ.setdefault(key, value)


def can_connect(host: str, port: int) -> bool:
    try:
        addresses = socket.getaddrinfo(
            host,
            port,
            type=socket.SOCK_STREAM,
        )
    except OSError:
        return False

    for family, socktype, proto, _, sockaddr in addresses:
        try:
            with socket.socket(family, socktype, proto) as sock:
                sock.settimeout(1)
                sock.connect(sockaddr)
                return True
        except OSError:
            continue

    return False


def should_bootstrap_local_postgres(project_root: Path) -> bool:
    if os.name != "nt":
        return False

    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if not command or command in NON_DB_COMMANDS:
        return False

    if os.getenv("VITAMATE_SKIP_LOCAL_POSTGRES_BOOTSTRAP") == "1":
        return False

    if os.getenv("VITAMATE_USE_SQLITE") == "1":
        return False

    django_env = os.getenv("DJANGO_ENV", "dev").strip().lower()
    if django_env not in {"", "dev", "development", "local"}:
        return False

    host = os.getenv("POSTGRES_HOST", "localhost").strip().lower()
    if host not in {"localhost", "127.0.0.1", "::1"}:
        return False

    try:
        port = int(os.getenv("POSTGRES_PORT", "5432"))
    except ValueError:
        return False

    if can_connect(host, port):
        return False

    return (project_root / "scripts" / "setup_postgres_portable.ps1").exists()


def ensure_local_postgres(project_root: Path) -> None:
    script_path = project_root / "scripts" / "setup_postgres_portable.ps1"
    print("Ensuring local PostgreSQL is running...", file=sys.stderr)
    try:
        subprocess.run(
            [
                "powershell",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(script_path),
            ],
            cwd=project_root,
            check=True,
        )
    except FileNotFoundError as exc:
        raise RuntimeError(
            "PowerShell was not found while trying to start local PostgreSQL."
        ) from exc
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(
            "Automatic local PostgreSQL startup failed. "
            "Run scripts\\setup_postgres_portable.ps1 manually."
        ) from exc


def main():
    """Run administrative tasks."""
    project_root = Path(__file__).resolve().parent
    load_local_env(project_root)
    if should_bootstrap_local_postgres(project_root):
        ensure_local_postgres(project_root)
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'vitamate_project.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH environment variable? Did you "
            "forget to activate a virtual environment?"
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == '__main__':
    main()
