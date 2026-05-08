# LDPlayer Run Guide (VitaMate)

## 1) Start backend on host machine

From `Implementation/vitamate_backend`:

```powershell
python manage.py migrate
.\scripts\start_dev_backend.ps1
```

Keep this terminal open.

## 2) Ensure emulator is connected

```powershell
adb devices
```

You should see a device, for example: `emulator-5554`.

## 3) Run Flutter app with explicit API URL

From `Implementation/vitamate_frontend`:

```powershell
flutter pub get
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## 4) If `10.0.2.2` does not work on your LDPlayer build

Use your host LAN IP instead (example):

```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://192.168.1.103:8000
```

## 5) Quick connectivity check

Open in emulator browser:

`http://10.0.2.2:8000/api/dashboard/`

Expected:
- `401/403` without token is normal (means network path works).
- `ERR_CONNECTION_REFUSED` means backend not running or wrong host/IP.
