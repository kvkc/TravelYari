@echo off
REM Yatra Planner - Release Build Script (Windows)
REM Reads API keys from .env file and builds with them

REM Load .env file if it exists
if exist .env (
    for /f "tokens=1,2 delims==" %%a in ('type .env ^| findstr /v "^#"') do (
        set %%a=%%b
    )
)

REM Check if GOOGLE_MAPS_API_KEY is set
if "%GOOGLE_MAPS_API_KEY%"=="" (
    echo Warning: GOOGLE_MAPS_API_KEY not set. Building without Google Maps.
    echo The app will use free OpenStreetMap instead.
    echo.
)

REM Build command based on argument
if "%1"=="apk" (
    echo Building Android APK...
    flutter build apk --release --dart-define=GOOGLE_MAPS_API_KEY=%GOOGLE_MAPS_API_KEY%
    goto :end
)
if "%1"=="appbundle" (
    echo Building Android App Bundle...
    flutter build appbundle --release --dart-define=GOOGLE_MAPS_API_KEY=%GOOGLE_MAPS_API_KEY%
    goto :end
)
if "%1"=="aab" (
    echo Building Android App Bundle...
    flutter build appbundle --release --dart-define=GOOGLE_MAPS_API_KEY=%GOOGLE_MAPS_API_KEY%
    goto :end
)
if "%1"=="ios" (
    echo Building iOS...
    flutter build ios --release --dart-define=GOOGLE_MAPS_API_KEY=%GOOGLE_MAPS_API_KEY%
    goto :end
)
if "%1"=="web" (
    echo Building Web...
    flutter build web --release --dart-define=GOOGLE_MAPS_API_KEY=%GOOGLE_MAPS_API_KEY%
    goto :end
)
if "%1"=="run" (
    echo Running debug build...
    flutter run --dart-define=GOOGLE_MAPS_API_KEY=%GOOGLE_MAPS_API_KEY%
    goto :end
)

echo Usage: build_release.bat [apk^|appbundle^|ios^|web^|run]
echo.
echo Make sure to create a .env file with your API keys.
echo See .env.example for the format.

:end
