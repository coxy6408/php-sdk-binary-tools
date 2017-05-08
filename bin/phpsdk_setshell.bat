@echo off

if not defined PHP_SDK_RUN_FROM_ROOT (
	echo This script should not be run directly.
	echo Use starter scripts looking like phpsdk-^<crt^>-^<arch^>.bat in the PHP SDK root instead.
	goto out_error
)


if "%1"=="" goto :help
if "%1"=="/?" goto :help
if "%1"=="-h" goto :help
if "%1"=="--help" goto :help
if "%2"=="" goto :help

set PHP_SDK_VC=%1
if /i not "%PHP_SDK_VC:~0,2%"=="vc" (
:malformed_vc_string
	echo Malformed CRT string "%1"
	set PHP_SDK_VC=
	goto out_error
)
if ""=="%PHP_SDK_VC:~2%" (
	goto malformed_vc_string
)
set /a TMP_CHK=%PHP_SDK_VC:~2%
if 11 gtr %TMP_CHK% (
	if "0"=="%TMP_CHK%" (
		if not "0"=="%PHP_SDK_VC:~2%" (
			set TMP_CHK=
			goto malformed_vc_string
		)
	)

	echo At least vc14 is required
	set PHP_SDK_VC=
	set TMP_CHK=
	goto out_error
)
set PHP_SDK_VC_NUM=%TMP_CHK%
set TMP_CHK=

if /i not "%2"=="x64" (
	if /i not "%2"=="x86" (
		echo Unsupported arch "%2"
		goto out_error
	)
)

set PHP_SDK_ARCH=%2

rem check OS arch
set TMPKEY=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion
reg query "%TMPKEY%" /v "ProgramFilesDir (x86)" >nul 2>nul
if not errorlevel 1 (
	set PHP_SDK_OS_ARCH=x64
) else (
	if /i "%PHP_SDK_ARCH%"=="x64" (
		echo 32-bit OS detected, native 64-bit toolchain is unavailable.
		goto out_error
	)
	set PHP_SDK_OS_ARCH=x86
)
set TMPKEY=

rem get vc base dir
if 15 gtr %PHP_SDK_VC_NUM% (
	if /i "%PHP_SDK_OS_ARCH%"=="x64" (
		set TMPKEY=HKLM\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\%PHP_SDK_VC:~2%.0\Setup\VC
	) else (
		set TMPKEY=HKLM\SOFTWARE\Microsoft\VisualStudio\%PHP_SDK_VC:~2%.0\Setup\VC
	)
	reg query !TMPKEY! /v ProductDir >nul 2>&1
	if errorlevel 1 (
		echo Couldn't determine VC%PHP_SDK_VC:~2% directory
		goto out_error;
	)
	for /f "tokens=2*" %%a in ('reg query !TMPKEY! /v ProductDir') do set PHP_SDK_VC_DIR=%%b
) else (
	rem vc15 support only for now, could parse out and pass on later
	for /f "tokens=1* delims=: " %%a in ('%~dp0\vswhere -nologo -version %PHP_SDK_VC_NUM% -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath -format text') do set PHP_SDK_VC_DIR=%%b\VC
	set VSCMD_ARG_no_logo=nologo
	if not exist "!PHP_SDK_VC_DIR!" (
		echo Could not determine '%PHP_SDK_VC%' directory
		goto out_error;
	)
)
set TMPKEY=

if 15 gtr %PHP_SDK_VC_NUM% (
	rem get sdk dir
	if /i "%PHP_SDK_OS_ARCH%"=="x64" (
		set TMPKEY=HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Microsoft SDKs\Windows\v8.1
	) else (
		set TMPKEY=HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v8.1
	)
	for /f "tokens=2*" %%a in ('reg query "!TMPKEY!" /v InstallationFolder') do (
		if exist "%%b\Include\um\Windows.h" (
			set PHP_SDK_WIN_SDK_DIR=%%b
		)
	)
	if not defined PHP_SDK_WIN_SDK_DIR (
		echo Windows SDK not found.
		goto out_error;
	)
	set TMPKEY=
)

if /i "%PHP_SDK_ARCH%"=="x64" (
	if 15 gtr %PHP_SDK_VC_NUM% (
		set PHP_SDK_VC_SHELL_CMD="!PHP_SDK_VC_DIR!\vcvarsall.bat" amd64
	) else (
		set PHP_SDK_VC_SHELL_CMD="!PHP_SDK_VC_DIR!\Auxiliary\Build\vcvarsall.bat" amd64
	)
) else (
	if 15 gtr %PHP_SDK_VC_NUM% (
		set PHP_SDK_VC_SHELL_CMD="!PHP_SDK_VC_DIR!\vcvarsall.bat" x86
	) else (
		set PHP_SDK_VC_SHELL_CMD="!PHP_SDK_VC_DIR!\Auxiliary\Build\vcvarsall.bat" x86
	)
)

rem echo Visual Studio path %PHP_SDK_VC_DIR%
rem echo Windows SDK path %PHP_SDK_WIN_SDK_DIR%


goto out

:help
	echo "Start Visual Studio command line for PHP SDK"
	echo "Usage: %0 vc arch" 
	echo nul

:out_error
	exit /b 3

:out
rem	echo Shell configuration complete
	exit /b 0

goto :eof

