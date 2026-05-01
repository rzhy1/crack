@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title Office 文档 John 破解工具（专业版）

REM 定义 ANSI 转义字符（用于彩色输出）
for /f %%a in ('echo prompt $E^|cmd') do set "ESC=%%a"
set OMP_WAIT_POLICY=active
set GOMP_SPINCOUNT=100000
REM =========================
REM 路径配置
REM =========================
set "JOHN_DIR=%~dp0john\run"
set "RULES_DIR=%~dp0john\run\rules"

set "SCRIPT_DIR=%~dp0"
set "HASH_FILE=%SCRIPT_DIR%hash.txt"

color 0A

echo ==============================================
echo   Office 文档 John the Ripper 破解（专业版）
echo ==============================================
echo.

set /p FILE=请输入 Office 文件路径:

set "FILE=%FILE:"=%"

if not exist "%FILE%" (
    echo ❌ 文件不存在
    pause
    exit /b
)

REM =========================
REM 1. 提取 hash
REM =========================
echo.
echo %ESC%[94m[[1/3] 提取 Office 哈希...%ESC%[0m

cd /d "%JOHN_DIR%"
del "%HASH_FILE%" 2>nul
py -u office2john.py "%FILE%" > "%HASH_FILE%"
for %%A in ("%HASH_FILE%") do if %%~zA equ 0 (
    echo ❌ 哈希提取失败
    pause
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Content '%HASH_FILE%' | Out-File '%HASH_FILE%.tmp' -Encoding utf8; Move-Item '%HASH_FILE%.tmp' '%HASH_FILE%' -Force"
echo ✔ 提取成功
type "%HASH_FILE%"
echo.


REM =========================
REM 2. 清理 hash（核心稳定版）
REM =========================
echo.
echo %ESC%[94m[[2/3] 清理哈希格式...%ESC%[0m

powershell -NoProfile -Command ^
"$c = Get-Content '%HASH_FILE%' -Raw; ^
if ($c -match '\$office\$.*') { $c = $matches[0] }; ^
if ($c -match '\$oldoffice\$.*') { $c = $matches[0] }; ^
if ($c -match ':::::') { $c = $c -replace ':::::.*$','' }; ^
$c = $c.Trim(); ^
Set-Content '%HASH_FILE%' $c"

echo ✔ 清理完成
type "%HASH_FILE%"
echo.

REM =========================
REM 3. 自动识别格式
REM =========================
set "FORMAT=office"
findstr /C:"$oldoffice$" "%HASH_FILE%" >nul && set "FORMAT=oldoffice"

echo 当前格式: !FORMAT!

REM 👉 复制到 John 目录（避免中文路径问题）
set "JOHN_HASH=%JOHN_DIR%\hash.txt"
copy "%HASH_FILE%" "%JOHN_HASH%" >nul

REM =========================
REM 开始破解
REM =========================
echo.
echo %ESC%[94m[[3/3] 开始破解...
echo.

REM ========= 阶段5 =========
echo.
echo %ESC%[94m[阶段5] 终极矩阵攻击：多字典 × 多规则%ESC%[0m

set "DICTS_DIR=%JOHN_DIR%\dicts"

REM 开始双重循环爆破
set "BUILTIN_RULES=Wordlist Jumbo KoreLogic"

for %%D in ("%DICTS_DIR%\*.lst" "%DICTS_DIR%\*.txt") do (
    
    echo.
    echo %ESC%[96m=================================================%ESC%[0m
    echo %ESC%[96m 🎯 当前挂载字典: %%~nxD %ESC%[0m
    echo %ESC%[96m=================================================%ESC%[0m

    REM 1️⃣ 应用 JtR 内置规则
    for %%R in (!BUILTIN_RULES!) do (
        echo %ESC%[93m [+] 应用内置强力规则: %%R %ESC%[0m
        
        call :RUN_JOHN "%%D" "%%R"
        if "!CRACKED!"=="1" goto show_pwd
    )

    REM 2️⃣ 应用 rules 文件夹里的自定义规则
    if exist "%RULES_DIR%\*.rule" (
        for %%r in ("%RULES_DIR%\*.rule" "%RULES_DIR%\*.conf") do (
            for /f "tokens=2 delims=:" %%n in ('findstr /I /C:"[List.Rules:" "%%r" 2^>nul') do (
                set "RULENAME=%%n"
                set "RULENAME=!RULENAME:]=!"
                set "RULENAME=!RULENAME: =!"
                
                if not "!RULENAME!"=="" (
                    echo %ESC%[95m [+] 应用外部规则文件: !RULENAME! %ESC%[0m
                    
                    call :RUN_JOHN "%%D" "!RULENAME!"
                    if "!CRACKED!"=="1" goto show_pwd
                )
            )
        )
    )

    REM 3️⃣ 纯字典无变异兜底
    REM 修复: 将小括号改为中括号，防止 CMD 循环崩溃
    echo %ESC%[93m [+] 进行纯字典爆破 [无变异兜底]... %ESC%[0m
    call :RUN_JOHN_NO_RULE "%%D"
    if "!CRACKED!"=="1" goto show_pwd
)

REM 字典阶段跑完没找到密码，跳过子程序区
goto skip_dict

REM ==========================================
REM 子程序区 [将核心调用隔离，彻底杜绝闪退]
REM ==========================================
:RUN_JOHN
set "DICT_ARG=%~1"
set "RULE_ARG=%~2"

john --format=!FORMAT!-opencl --wordlist="!DICT_ARG!" --rules="!RULE_ARG!" "%JOHN_HASH%" --devices=1

set "CRACKED=0"
john --show "%JOHN_HASH%" 2>nul | find "1 password hash cracked" >nul
if not errorlevel 1 set "CRACKED=1"
exit /b

:RUN_JOHN_NO_RULE
set "DICT_ARG=%~1"

john --format=!FORMAT!-opencl --wordlist="!DICT_ARG!" "%JOHN_HASH%" --devices=1

set "CRACKED=0"
john --show "%JOHN_HASH%" 2>nul | find "1 password hash cracked" >nul
if not errorlevel 1 set "CRACKED=1"
exit /b

REM ==========================================

:skip_dict

REM =========================
REM 输出结果（专业修复版）
REM =========================
:show_pwd
setlocal DisableDelayedExpansion

echo.
echo =========================
echo 破解结果
echo =========================

powershell -NoProfile -Command ^
    "$john = '%JOHN_DIR%\john.exe'; "^
    "$hash = '%JOHN_HASH%'; "^
    "$output = & $john --show $hash 2>&1; "^
    "if ($output -match '1 password hash cracked') { "^
    "  $line = $output | Where-Object { $_ -notmatch 'password hash cracked|left' -and $_ -match ':' } | Select-Object -First 1; "^
    "  if ($line) { "^
    "    $pwd = $line -replace '^.*?:',''; "^
    "    $pwd = $pwd.Trim(); "^
    "    Write-Host '✔ 破解成功！' -ForegroundColor Green; "^
    "    Write-Host ''; "^
    "    Write-Host '密码:' -NoNewline; "^
    "    Write-Host $pwd -ForegroundColor Blue; "^
    "  } else { "^
    "    Write-Host '❌ 密码提取异常' -ForegroundColor DarkYellow "^
    "  } "^
    "} else { "^
    "  Write-Host '❌ 未找到密码（所有破解阶段已结束）' -ForegroundColor Red "^
    "}"

echo =========================
pause
exit /b