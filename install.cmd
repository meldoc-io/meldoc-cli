@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: Meldoc CLI Installer for Windows CMD
:: Usage: curl -fsSL https://meldoc.io/install.cmd -o install.cmd && install.cmd && del install.cmd
:: ============================================================================

:: Configuration
set "TOOL_NAME=meldoc"
set "GITHUB_REPO=meldoc-io/meldoc-cli"
set "GITHUB_RELEASES=https://github.com/%GITHUB_REPO%/releases"
set "GITHUB_API=https://api.github.com/repos/%GITHUB_REPO%"

:: Default values
set "VERSION=latest"
set "FORCE=0"
set "QUIET=0"

:: Parse arguments
:parse_args
if "%~1"=="" goto :done_args
if /i "%~1"=="--version" (
    set "VERSION=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--force" (
    set "FORCE=1"
    shift
    goto :parse_args
)
if /i "%~1"=="--quiet" (
    set "QUIET=1"
    shift
    goto :parse_args
)
if /i "%~1"=="-q" (
    set "QUIET=1"
    shift
    goto :parse_args
)
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="-h" goto :show_help
shift
goto :parse_args
:done_args

:: Banner
if "%QUIET%"=="0" (
    echo.
    echo                  _     _            
    echo   _ __ ___   ___^| ^| __^| ^| ___   ___ 
    echo  ^| '_ ` _ \ / _ \ ^|/ _` ^|/ _ \ / __^|
    echo  ^| ^| ^| ^| ^|  __/ ^| ^(_^| ^| ^(_) ^| ^(__ 
    echo  ^|_^| ^|_^| ^|_\___^|_^|\__,_^|\___/ \___^|
    echo.
    echo  Meldoc CLI Installer for Windows
    echo.
)

:: Check curl is available
where curl >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] curl is required but not found.
    echo Please install curl or use PowerShell installer:
    echo   irm https://meldoc.io/install.ps1 ^| iex
    exit /b 1
)

:: Detect architecture
set "ARCH=amd64"
if "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "ARCH=arm64"
if "%PROCESSOR_ARCHITEW6432%"=="ARM64" set "ARCH=arm64"

if "%QUIET%"=="0" echo [INFO] Detected architecture: windows/%ARCH%

:: Resolve version
if "%QUIET%"=="0" echo [INFO] Resolving version...

if "%VERSION%"=="latest" (
    :: Get latest version from GitHub API
    for /f "tokens=*" %%i in ('curl -fsSL "%GITHUB_API%/releases/latest" 2^>nul ^| findstr /r "tag_name"') do (
        set "LINE=%%i"
    )
    :: Extract version from JSON (crude but works)
    for /f "tokens=2 delims=:," %%a in ("!LINE!") do (
        set "VERSION_TAG=%%~a"
    )
    :: Clean up the version tag
    set "VERSION_TAG=!VERSION_TAG: =!"
    set "VERSION_TAG=!VERSION_TAG:"=!"
    
    if "!VERSION_TAG!"=="" (
        echo [ERROR] Could not determine latest version
        exit /b 1
    )
) else (
    :: User provided version
    set "VERSION_TAG=%VERSION%"
    if not "!VERSION_TAG:~0,1!"=="v" set "VERSION_TAG=v%VERSION%"
)

:: Remove 'v' prefix for artifact naming
set "RESOLVED_VERSION=!VERSION_TAG:~1!"

if "%QUIET%"=="0" echo [INFO] Version: !VERSION_TAG!

:: Set target directory
set "TARGET_DIR=%LOCALAPPDATA%\Programs\%TOOL_NAME%\bin"

if "%QUIET%"=="0" echo [INFO] Install directory: %TARGET_DIR%

:: Create target directory
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

:: Check existing installation
set "DEST_PATH=%TARGET_DIR%\%TOOL_NAME%.exe"

if exist "%DEST_PATH%" (
    if "%FORCE%"=="0" (
        echo [WARN] Already installed at: %DEST_PATH%
        echo Use --force to overwrite
        exit /b 0
    )
)

:: Create temp directory
set "TEMP_DIR=%TEMP%\meldoc-install-%RANDOM%"
mkdir "%TEMP_DIR%" 2>nul

:: Build artifact name
set "ARTIFACT=%TOOL_NAME%-!RESOLVED_VERSION!-windows-%ARCH%.zip"
set "URL=%GITHUB_RELEASES%/download/!VERSION_TAG!/%ARTIFACT%"

if "%QUIET%"=="0" (
    echo [INFO] Downloading %TOOL_NAME% !VERSION_TAG!...
    echo        From: %URL%
)

:: Download artifact
curl -fsSL "%URL%" -o "%TEMP_DIR%\%ARTIFACT%"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Download failed
    echo Please check:
    echo   - Version exists: !VERSION_TAG!
    echo   - Releases page: %GITHUB_RELEASES%
    rd /s /q "%TEMP_DIR%" 2>nul
    exit /b 1
)

if "%QUIET%"=="0" echo [OK] Downloaded successfully

:: Extract archive using PowerShell (available on all modern Windows)
if "%QUIET%"=="0" echo [INFO] Extracting archive...

powershell -NoProfile -Command "Expand-Archive -Path '%TEMP_DIR%\%ARTIFACT%' -DestinationPath '%TEMP_DIR%' -Force" 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to extract archive
    rd /s /q "%TEMP_DIR%" 2>nul
    exit /b 1
)

:: Find and install binary
set "BIN_PATH=%TEMP_DIR%\%TOOL_NAME%.exe"
if not exist "%BIN_PATH%" (
    :: Search in subdirectories
    for /r "%TEMP_DIR%" %%f in (%TOOL_NAME%.exe) do (
        set "BIN_PATH=%%f"
        goto :found_binary
    )
    echo [ERROR] Binary not found after extraction
    rd /s /q "%TEMP_DIR%" 2>nul
    exit /b 1
)
:found_binary

:: Install binary
if "%QUIET%"=="0" echo [INFO] Installing binary...

copy /y "%BIN_PATH%" "%DEST_PATH%" >nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to copy binary to %DEST_PATH%
    rd /s /q "%TEMP_DIR%" 2>nul
    exit /b 1
)

:: Cleanup
rd /s /q "%TEMP_DIR%" 2>nul

:: Success message
if "%QUIET%"=="1" (
    echo %DEST_PATH%
) else (
    echo.
    echo ===================================================================
    echo   [OK] Installation successful!
    echo ===================================================================
    echo.
    echo   Location: %DEST_PATH%
    echo.
    
    :: Check if in PATH and add if needed
    echo %PATH% | findstr /i /c:"%TARGET_DIR%" >nul
    if %ERRORLEVEL% neq 0 (
        echo   [INFO] Adding to PATH...
        echo.
        
        :: Use PowerShell to modify PATH in registry (avoids setx 1024-char limit)
        powershell -NoProfile -Command "$currentPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User'); if ($null -eq $currentPath) { $currentPath = '' }; $normalizedTarget = '%TARGET_DIR%'.TrimEnd('\'); $entries = $currentPath -split ';' | ForEach-Object { $_.TrimEnd('\') }; $alreadyInPath = $entries | Where-Object { $_.ToLower() -eq $normalizedTarget.ToLower() }; if (-not $alreadyInPath) { $newPath = if ($currentPath -eq '') { '%TARGET_DIR%' } else { \"$currentPath;%TARGET_DIR%\" }; [System.Environment]::SetEnvironmentVariable('PATH', $newPath, 'User'); Write-Host '[OK] Added to user PATH' } else { Write-Host '[OK] Already in PATH' }" 2>nul
        
        if %ERRORLEVEL% neq 0 (
            :: Fallback to setx if PowerShell fails
            echo   [WARN] PowerShell method failed, trying setx...
            echo   [WARN] Note: setx has a 1024 character limit
            setx PATH "%PATH%;%TARGET_DIR%" >nul 2>&1
            if %ERRORLEVEL% equ 0 (
                echo   [OK] Added to PATH using setx
            ) else (
                echo   [ERROR] Failed to add to PATH automatically
                echo.
                echo   Please add manually:
                echo     1. Open: sysdm.cpl
                echo     2. Advanced -^> Environment Variables
                echo     3. Add to PATH: %TARGET_DIR%
                echo.
            )
        ) else (
            echo.
            echo   Note: Restart CMD or open a new terminal for changes to take effect
            echo.
        )
        
        :: Also set PATH for current session
        set PATH=%PATH%;%TARGET_DIR%
    ) else (
        echo   [OK] PATH already configured
        echo.
    )
    
    echo   Next step: configure Meldoc (PATH, MCP, login)
    echo.
    echo   To configure PATH, MCP, and login — run this in a new terminal:
    echo.
    echo     %DEST_PATH% setup
    echo.
    echo   (This path works even if meldoc is not in your PATH yet.)
    echo.
    
    echo   Get started:
    echo     meldoc --help
    echo     meldoc init
    echo.
    echo   Documentation:
    echo     https://public.meldoc.io/meldoc/cli
    echo.
    echo   Uninstall:
    echo     del "%DEST_PATH%"
    echo.
    echo ===================================================================
)

exit /b 0

:show_help
echo.
echo Meldoc CLI Installer for Windows
echo.
echo Usage: install.cmd [OPTIONS]
echo.
echo Options:
echo   --version VERSION   Install specific version (default: latest)
echo   --force             Overwrite existing installation
echo   --quiet, -q         Minimal output (for CI/CD)
echo   --help, -h          Show this help message
echo.
echo Examples:
echo   install.cmd                    Install latest version
echo   install.cmd --version v1.0.1   Install specific version
echo   install.cmd --force            Force reinstall
echo.
echo One-liner installation:
echo   curl -fsSL https://meldoc.io/install.cmd -o install.cmd ^&^& install.cmd ^&^& del install.cmd
echo.
exit /b 0
