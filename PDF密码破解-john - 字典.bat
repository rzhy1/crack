@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title PDF 文档 John 破解工具（专业版）

for /f %%a in ('echo prompt $E^|cmd') do set "ESC=%%a"
set OMP_WAIT_POLICY=active
set GOMP_SPINCOUNT=100000

:: 路径配置
set "JOHN_DIR=%~dp0john\run"
set "RULES_DIR=%~dp0john\run\rules"
set "SCRIPT_DIR=%~dp0"
set "HASH_FILE=%SCRIPT_DIR%hash.txt"

:: 核心：切换到 John 目录，此后所有 john 操作均基于当前目录，避免路径冒号
cd /d "%JOHN_DIR%" || (
    echo ❌ 无法进入 John 目录
    pause
    exit /b
)

color 0A
echo ==============================================
echo   PDF 文档 John 破解工具（专业版）
echo ==============================================
echo.

set /p FILE=请输入 PDF 文件路径:
set "FILE=%FILE:"=%"

if not exist "%FILE%" (
    echo ❌ 文件不存在
    pause
    exit /b
)

:: ========= 1. 提取哈希 =========
echo.
echo %ESC%[94m[[1/3] 提取 PDF 哈希...%ESC%[0m

if not exist "pdf2john.py" (
    echo ❌ 未找到 pdf2john.py，请放入 %JOHN_DIR%
    pause
    exit /b
)

del "%HASH_FILE%" 2>nul
py -u pdf2john.py "%FILE%" > "%HASH_FILE%"
for %%A in ("%HASH_FILE%") do if %%~zA equ 0 (
    echo ❌ 哈希提取失败
    pause
    exit /b
)

:: 提取 $pdf$ 行到工作文件 hash.txt → 替换为 !HASH_FILE!
set "CLEAN_HASH="
for /f "usebackq delims=" %%i in ("%HASH_FILE%") do (
    echo %%i | find "$pdf$" >nul
    if not errorlevel 1 (
        set "CLEAN_HASH=%%i"
        goto :got_hash
    )
)
:got_hash
if not defined CLEAN_HASH (
    echo ❌ 未找到有效 PDF 哈希
    pause
    exit /b
)
echo !CLEAN_HASH! > "!HASH_FILE!"

echo ✔ 提取成功
type "!HASH_FILE!"
echo.

:: 二次清洗保底
echo %ESC%[94m[[2/3] 确认哈希格式...%ESC%[0m
(for /f "usebackq delims=" %%i in ("!HASH_FILE!") do (
    echo %%i | find "$pdf$" >nul && echo %%i
)) > "!HASH_FILE!.tmp"
move /y "!HASH_FILE!.tmp" "!HASH_FILE!" >nul
echo ✔ 哈希格式确认完毕
type "!HASH_FILE!"
echo.

:: ========= 3. 破解准备 =========
set "FORMAT=pdf"
echo 当前格式: !FORMAT!
echo.
echo %ESC%[94m[[3/3] 开始破解...%ESC%[0m

:: ---------- 阶段5 ----------
echo.
echo %ESC%[94m[阶段5] 字典 × 规则攻击%ESC%[0m
set "BUILTIN_RULES=Wordlist Jumbo KoreLogic"

for %%D in (dicts\*.lst dicts\*.txt) do (
    echo.
    echo %ESC%[96m=================================================%ESC%[0m
    echo %ESC%[96m 🎯 字典: %%~nxD %ESC%[0m
    echo %ESC%[96m=================================================%ESC%[0m

    for %%R in (!BUILTIN_RULES!) do (
        echo %ESC%[93m [+] 内置规则: %%R %ESC%[0m
        call :RUN_DICT "%%D" "%%R"
        if "!CRACKED!"=="1" goto show_pwd
    )

    if exist "%RULES_DIR%\*.rule" (
        for %%r in ("%RULES_DIR%\*.rule" "%RULES_DIR%\*.conf") do (
            for /f "tokens=2 delims=:" %%n in ('findstr /I /C:"[List.Rules:" "%%r" 2^>nul') do (
                set "RULENAME=%%n"
                set "RULENAME=!RULENAME:]=!"
                set "RULENAME=!RULENAME: =!"
                if not "!RULENAME!"=="" (
                    echo %ESC%[95m [+] 外部规则: !RULENAME! %ESC%[0m
                    call :RUN_DICT "%%D" "!RULENAME!"
                    if "!CRACKED!"=="1" goto show_pwd
                )
            )
        )
    )

    echo %ESC%[93m [+] 纯字典爆破（兜底）%ESC%[0m
    call :RUN_DICT_NO_RULE "%%D"
    if "!CRACKED!"=="1" goto show_pwd
)

echo.
echo %ESC%[91m所有阶段结束，未找到密码%ESC%[0m
pause
exit /b

:: ==================== 子程序 ====================
:CHECK_CRACK
john --show "!HASH_FILE!" 2>nul | find "1 password hash cracked" >nul
exit /b

:RUN_DICT
set "DICT=%~1"
set "RULE=%~2"
john --format=%FORMAT%-opencl --wordlist="%DICT%" --rules="%RULE%" "!HASH_FILE!" --devices=1
set "CRACKED=0"
call :CHECK_CRACK && set "CRACKED=1"
exit /b

:RUN_DICT_NO_RULE
set "DICT=%~1"
john --format=%FORMAT%-opencl --wordlist="%DICT%" "!HASH_FILE!" --devices=1
set "CRACKED=0"
call :CHECK_CRACK && set "CRACKED=1"
exit /b

:: ==================== 显示密码 ====================
:show_pwd
setlocal DisableDelayedExpansion
echo.
echo =========================
echo 破解结果
echo =========================

powershell -NoProfile -Command ^
    "$johnExe = '%JOHN_DIR%\john.exe'; "^
    "$hash = '%HASH_FILE%'; "^
    "$output = & $johnExe --show $hash 2>&1; "^
    "$line = $output | Where-Object { $_ -match ':' -and $_ -notmatch 'password hash cracked|No password|Loaded' } | Select-Object -First 1; "^
    "if ($line) { "^
    "    $pwd = ($line -split ':',2)[1]; "^
    "    Write-Host '✔ 破解成功！' -ForegroundColor Green; "^
    "    Write-Host ''; "^
    "    Write-Host '密码:' -NoNewline -ForegroundColor Gray; "^
    "    Write-Host $pwd -ForegroundColor Red "^
    "} else { "^
    "    Write-Host '❌ 未找到密码（所有破解阶段已结束）' -ForegroundColor Red "^
    "}"

echo =========================
endlocal
pause
exit /b