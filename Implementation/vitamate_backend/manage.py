#!/usr/bin/env python
"""Django's command-line utility for administrative tasks."""
import os
import socket
import subprocess
import sys
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import urlopen


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


def configure_local_postgres_client(project_root: Path) -> None:
    """Use the portable libpq when Windows blocks psycopg's bundled DLL."""
    if os.name != "nt" or os.getenv("VITAMATE_USE_SQLITE") == "1":
        return

    django_env = os.getenv("DJANGO_ENV", "dev").strip().lower()
    if django_env not in {"", "dev", "development", "local"}:
        return

    portable_root = project_root / ".local"
    postgres_bins = sorted(
        portable_root.glob("postgresql-*/pgsql/bin"),
        reverse=True,
    )
    postgres_bin = next(
        (path for path in postgres_bins if (path / "libpq.dll").exists()),
        None,
    )
    if postgres_bin is None:
        return

    current_path = os.environ.get("PATH", "")
    path_entries = current_path.split(os.pathsep) if current_path else []
    postgres_bin_text = str(postgres_bin.resolve())
    if postgres_bin_text.lower() not in {entry.lower() for entry in path_entries}:
        os.environ["PATH"] = os.pathsep.join([postgres_bin_text, *path_entries])

    # The bundled psycopg extension can be rejected by Windows Application
    # Control. The pure-Python implementation still uses the same local libpq.
    os.environ.setdefault("PSYCOPG_IMPL", "python")


def can_connect(host: str, port: int) -> bool:
    timeout = float(os.getenv("VITAMATE_DB_CONNECT_TIMEOUT", "0.25"))
    normalized_host = host.strip().lower()
    if normalized_host in {"localhost", "127.0.0.1", "::1"}:
        addresses = []
        if normalized_host in {"localhost", "127.0.0.1"}:
            addresses.append(
                (socket.AF_INET, socket.SOCK_STREAM, 0, "", ("127.0.0.1", port))
            )
        if normalized_host in {"localhost", "::1"}:
            addresses.append(
                (socket.AF_INET6, socket.SOCK_STREAM, 0, "", ("::1", port, 0, 0))
            )
    else:
        try:
            addresses = socket.getaddrinfo(
                host,
                port,
                type=socket.SOCK_STREAM,
            )
        except OSError:
            return False

    if not addresses:
        return False

    for family, socktype, proto, _, sockaddr in addresses:
        try:
            with socket.socket(family, socktype, proto) as sock:
                sock.settimeout(timeout)
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
        postgres_port = int(os.getenv("POSTGRES_PORT", "5432"))
    except ValueError as exc:
        raise RuntimeError("POSTGRES_PORT must be a valid integer.") from exc

    try:
        subprocess.run(
            [
                "powershell",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(script_path),
                "-DbName",
                os.getenv("POSTGRES_DB", "vitamate"),
                "-DbUser",
                os.getenv("POSTGRES_USER", "vitamate"),
                "-DbPassword",
                os.getenv("POSTGRES_PASSWORD", "vitamate"),
                "-PgHost",
                os.getenv("POSTGRES_HOST", "localhost"),
                "-Port",
                str(postgres_port),
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


def local_ai_endpoint() -> tuple[str, int, str] | None:
    base_url = os.getenv("AI_MEALS_BASE_URL", "http://127.0.0.1:8010").rstrip("/")
    parsed = urlparse(base_url)
    host = (parsed.hostname or "").strip().lower()
    if parsed.scheme not in {"http", "https"}:
        return None
    if host not in {"localhost", "127.0.0.1", "::1"}:
        return None
    try:
        port = parsed.port or (443 if parsed.scheme == "https" else 80)
    except ValueError:
        return None
    return host, port, base_url


def should_bootstrap_local_ai(project_root: Path) -> bool:
    if os.name != "nt" or "runserver" not in sys.argv[1:]:
        return False
    if os.getenv("VITAMATE_SKIP_AI_SERVICE_BOOTSTRAP") == "1":
        return False

    django_env = os.getenv("DJANGO_ENV", "dev").strip().lower()
    if django_env not in {"", "dev", "development", "local"}:
        return False
    if local_ai_endpoint() is None:
        return False
    return (project_root / "scripts" / "run_ai_service.ps1").exists()


def wait_for_local_ai(base_url: str, host: str, port: int) -> None:
    started_at = time.monotonic()
    listener_deadline = time.monotonic() + float(
        os.getenv("VITAMATE_AI_START_TIMEOUT_SECONDS", "180")
    )
    next_progress_notice = started_at + 10
    while time.monotonic() < listener_deadline:
        if can_connect(host, port):
            break
        now = time.monotonic()
        if now >= next_progress_notice:
            elapsed = int(now - started_at)
            print(
                f"VitaMate AI is still starting ({elapsed}s elapsed)...",
                file=sys.stderr,
            )
            next_progress_notice = now + 10
        time.sleep(0.5)
    else:
        raise RuntimeError(
            f"VitaMate AI service did not start on {host}:{port}. "
            "Check .local\\vitamate_ai_runtime\\logs\\auto_service.stderr.log."
        )

    print(
        "VitaMate AI process started. Loading models; the first launch may "
        "take several minutes...",
        file=sys.stderr,
    )
    readiness_timeout = float(
        os.getenv("VITAMATE_AI_READY_TIMEOUT_SECONDS", "300")
    )
    try:
        with urlopen(f"{base_url}/readyz", timeout=readiness_timeout) as response:
            if response.status != 200:
                raise RuntimeError(
                    f"VitaMate AI readiness check returned HTTP {response.status}."
                )
    except HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:500]
        raise RuntimeError(
            f"VitaMate AI pipeline is not ready (HTTP {exc.code}): {detail}"
        ) from exc
    except (URLError, TimeoutError, OSError) as exc:
        raise RuntimeError(
            f"VitaMate AI readiness check failed at {base_url}/readyz: {exc}"
        ) from exc


def ensure_local_ai(project_root: Path) -> None:
    endpoint = local_ai_endpoint()
    if endpoint is None:
        return
    host, port, base_url = endpoint

    if not can_connect(host, port):
        package_root = Path(
            os.getenv(
                "VITAMATE_AI_PACKAGE_ROOT",
                str(project_root.parent / ".local" / "vitamate_ai_runtime"),
            )
        ).resolve()
        runtime_python = package_root / ".venv" / "Scripts" / "python.exe"
        if not runtime_python.exists():
            raise RuntimeError(
                "VitaMate AI runtime is not installed. Run "
                "scripts\\install_ai_service.ps1, or set "
                "VITAMATE_SKIP_AI_SERVICE_BOOTSTRAP=1 to start without it."
            )

        logs_dir = package_root / "logs"
        logs_dir.mkdir(parents=True, exist_ok=True)
        stdout_path = logs_dir / "auto_service.stdout.log"
        stderr_path = logs_dir / "auto_service.stderr.log"
        command = [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(project_root / "scripts" / "run_ai_service.ps1"),
            "-PackageRoot",
            str(package_root),
            "-Port",
            str(port),
        ]
        print(f"Starting VitaMate AI service on {host}:{port}...", file=sys.stderr)
        try:
            with stdout_path.open("a", encoding="utf-8") as stdout_log, stderr_path.open(
                "a", encoding="utf-8"
            ) as stderr_log:
                subprocess.Popen(
                    command,
                    cwd=project_root,
                    stdin=subprocess.DEVNULL,
                    stdout=stdout_log,
                    stderr=stderr_log,
                    creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
                )
        except FileNotFoundError as exc:
            raise RuntimeError(
                "PowerShell was not found while trying to start VitaMate AI."
            ) from exc

    wait_for_local_ai(base_url, host, port)
    print(f"VitaMate AI service is ready at {base_url}.", file=sys.stderr)


def main():
    """Run administrative tasks."""
    project_root = Path(__file__).resolve().parent
    load_local_env(project_root)
    configure_local_postgres_client(project_root)
    if should_bootstrap_local_postgres(project_root):
        ensure_local_postgres(project_root)
    if should_bootstrap_local_ai(project_root):
        ensure_local_ai(project_root)
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
