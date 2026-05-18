@echo off
setlocal

REM Project root directory
set ROOT_DIR=%~dp0

REM Conda environment name (adjust if needed)
set ENV_NAME=paperddl

pushd "%ROOT_DIR%"

REM Ensure server .env exists
if not exist "server\.env" (
  copy "server\.env.example" "server\.env" >nul
)

REM Activate conda environment
call conda activate %ENV_NAME%
if errorlevel 1 (
  echo Failed to activate conda environment: %ENV_NAME%
  echo Please check the environment name or your conda installation.
  popd
  exit /b 1
)

REM Start server and web dev in separate windows
start "paperddl server" cmd /k "npm run server:dev"
start "paperddl web" cmd /k "npm run web:dev"

popd
endlocal
