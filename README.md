# Nexa Attendance

Nexa is an Android attendance assignment with Admin and Staff roles. An Admin can view and add staff, open a staff profile, and enrol that person's face from three camera captures. A Staff user can mark attendance only after backend face verification; accepted attendance stores the server timestamp, selfie, and captured location.

## Technology and architecture

- **Mobile:** Flutter, Dart, Riverpod, Freezed, Dio, Camera, Geolocator, and secure local session storage.
- **API:** FastAPI with layered domain, service, repository, and adapter boundaries.
- **Face verification:** OpenCV YuNet face detection and SFace embeddings with cosine matching on the backend.
- **Development data:** Process-memory repository, demo authentication, and in-memory image storage.
- **Production-ready adapters:** Supabase Auth, PostgreSQL, and private Supabase Storage. These adapters are included but are not required for the local assignment demo.

The mobile client uses MVVM: views render immutable state, Riverpod viewmodels coordinate workflows, repositories map feature operations, and services own transport, session, camera, and location access. The client never declares a face match. The API performs face detection, enrolment, comparison, authorization, and attendance persistence.

## Demo credentials

| Role | Email | Password |
|---|---|---|
| Admin | `admin@attendance.example` | `Admin123!` |
| Staff | `staff.a@attendance.example` | `Staff123!` |

Use **Demo Staff A** (`DEMO-001`) for the complete enrolment and attendance flow. Staff added through the local Admin flow do not automatically receive login credentials.

## Run locally

Prerequisites:

- Flutter with Dart 3.10 or newer
- Python 3.12–3.14
- `uv`
- An Android emulator or Android phone with camera and precise location access

From the repository root, install the API dependencies and fetch the checksum-verified face models:

```bash
cp .env.example .env
cp apps/mobile/.env.example apps/mobile/.env

cd services/api
uv sync --dev --group face
cd ../..
services/api/.venv/bin/python scripts/fetch_models.py
```

The root `.env` configures FastAPI and is loaded automatically by the backend settings. `apps/mobile/.env` configures the API URL compiled into the Flutter application. Both local files are ignored by Git; their `.env.example` templates are committed.

The mobile example uses the Android emulator address:

```dotenv
API_BASE_URL=http://10.0.2.2:8000/api/v1
```

For a physical phone, edit `apps/mobile/.env` and replace it with the development computer's LAN address, for example:

```dotenv
API_BASE_URL=http://192.168.1.25:8000/api/v1
```

Start the local API with real face recognition:

```bash
cd services/api
.venv/bin/uvicorn attendance_api.main:app \
  --host 0.0.0.0 --port 8000
```

Confirm that `http://127.0.0.1:8000/api/v1/health/live` returns `{"status":"alive"}`.

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define-from-file=.env
```

Add `-d DEVICE_ID` when more than one Flutter device is available. The API URL is a compile-time setting, so rebuild or rerun the application after changing `apps/mobile/.env`. Cleartext HTTP is enabled only in debug builds.

## Demo flow

1. Sign in as Admin.
2. Open **Demo Staff A** and enrol the face using three well-lit captures of the same consenting person.
3. Sign out and sign in as Staff.
4. Mark attendance using the same person's face and grant precise location access.
5. Verify the receipt contains the timestamp, attendance date, coordinates, and location accuracy.
6. Try marking attendance again to verify the daily duplicate guard.

The [end-to-end screen recording](salary_box_assing_demo.mp4) is included in the repository and demonstrates this flow on a physical Android device.

## Reset the local demo

The development repository is held only in API process memory. Stop and restart the FastAPI process to remove the registered face, attendance records, sessions, added staff, and stored images. Demo Staff A and both demo login accounts are recreated automatically in their initial unenrolled state.

To also clear the installed app's saved session before recording a fresh demonstration:

```bash
adb shell pm clear com.example.attendance.attendance_mobile
```

Then restart the API and launch the app again.

## Validation

Automated checks:

```bash
cd services/api
.venv/bin/ruff format --check .
.venv/bin/ruff check .
.venv/bin/mypy src
.venv/bin/pytest -q

cd ../../apps/mobile
dart run build_runner build --delete-conflicting-outputs
dart run tool/compact_generated.dart
dart run tool/check_format.dart
dart run tool/check_file_size.dart
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=.env
```

Current results: all backend checks and 3 API tests pass; all mobile checks and 5 Flutter tests pass; the debug APK builds successfully.

Physical-device verification was completed on an SM-S906E (`android-arm64`) running Android 16/API 36. The application built, installed, and the complete Admin enrolment and Staff attendance flow was exercised against the local FastAPI service. The repeated three-photo camera flow was also verified on this device.

The submitted APK SHA-256 is recorded in `artifacts/attendance-debug.apk.sha256`.

## Assumptions and limitations

- Local data is intentionally ephemeral and resets whenever the API restarts.
- `FACE_PROVIDER=opencv` is required for the real camera flow. `FACE_PROVIDER=demo` is only a deterministic automated-test fixture and is not face recognition.
- The local Admin flow creates a staff record but does not create a new login account. The supplied Staff account is used for the full demo.
- The submitted APK is a debug build for assignment evaluation, not a production-signed Play Store release.
- Face matching uses a single attendance selfie and does not provide certified liveness or presentation-attack detection.
- Location and Android's mocked-location flag provide useful evidence but are not fraud-proof.
- The included Supabase adapters have not been verified against a hosted Supabase project; the demonstrated assignment flow uses the documented local backend.
- Formal population accuracy, fairness calibration, accessibility certification, and production deployment are outside this assignment's demonstrated scope.

## Submission artifacts

- GitHub source repository
- Debug APK and SHA-256 checksum
- End-to-end screen recording
- Authentic AI conversation JSON export used during development
