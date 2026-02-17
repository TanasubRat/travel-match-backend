# Copilot Instructions for travel_match_app

## Project Overview
- **travel_match_app** is a cross-platform Flutter application for travel group matching, with a Tinder-style swipe interface.
- The project includes a Dart/Flutter frontend (`lib/`, `assets/`, `test/`) and a Node.js backend (`backend/`).
- Mobile, web, and desktop (Windows, macOS, Linux) targets are supported via platform-specific folders.

## Architecture & Key Components
- **Frontend (Flutter):**
  - Main entry: `lib/main.dart`.
  - UI screens: `lib/screens/` (e.g., onboarding, login, register, tabbed navigation).
  - API communication: `lib/service/api_service.dart` (handles HTTP requests to backend).
  - UI constants: `lib/ui_constants.dart`.
  - Widgets: `lib/widgets/` (custom UI components).
  - Assets: `assets/` (images, places data).
- **Backend (Node.js/Express):**
  - Entry: `backend/server.js`.
  - Models: `backend/models/` (e.g., `User.js`, `Group.js`, `Place.js`, `Swipe.js`).
  - Routes: `backend/routes/` (REST endpoints for auth, groups, places, swipes).
  - Middleware: `backend/middleware/` (e.g., authentication logic).
  - Data seeding: `backend/places_seed.json`, `backend/seed_places.js`.

## Developer Workflows
- **Flutter App:**
  - Run: `flutter run` (platform auto-detected) or specify with `-d` (e.g., `flutter run -d chrome`).
  - Build: `flutter build <platform>` (e.g., `flutter build apk`, `flutter build web`).
  - Test: `flutter test` (see `test/widget_test.dart` for example).
- **Backend:**
  - Install deps: `cd backend && npm install`
  - Run server: `node server.js` (default port 3000)
  - Seed places: `node seed_places.js`

## Project-Specific Conventions
- **API URLs** are hardcoded in `api_service.dart` and tests; update as needed for local/production.
- **Assets** are referenced in `pubspec.yaml` under `flutter/assets`.
- **State management** is handled locally in widgets; no global state library is used.
- **Testing:** Only basic widget test exists; expand as needed in `test/`.
- **Platform builds:** Use platform folders (`android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`) for native configuration.

## Integration & Data Flow
- **Frontend** communicates with **backend** via REST API (see `api_service.dart` and backend `routes/`).
- **Backend** uses MongoDB (connection details not included here; see `backend/models/`).
- **Authentication** handled via backend middleware and routes.

## Examples
- To add a new screen: create a Dart file in `lib/screens/`, add to navigation in `main.dart` or tab files.
- To add a new API endpoint: create a route in `backend/routes/`, update `api_service.dart` if needed.

---
For more, see `README.md` and inspect `pubspec.yaml` and `backend/package.json` for dependencies.
