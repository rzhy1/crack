@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title PDF 文档 Hashcat 破解工具（专业多阶段版）

REM 定义 ANSI 转义字符（用于彩色输出）
for /f %%a in ('echo prompt $E^|cmd') do set "ESC=%%a"

REM =========================
REM 路径配置
REM =========================
set "HASHCAT_DIR=%~dp0hashcat"
set "JOHN_DIR=%~dp0john\run"
set "SCRIPT_DIR=%~dp0"
set "HASH_FILE=%SCRIPT_DIR%hash.txt"
set "PDF2JOHN=%JOHN_DIR%\pdf2john.py"

color 0A

echo %ESC%[92m==============================================%ESC%[0m
echo %ESC%[92m  PDF 文档 Hashcat 破解工具（多阶段专业版）%ESC%[0m
echo %ESC%[92m==============================================%ESC%[0m
echo.

set /p FILE=请输入 PDF 文件路径:
set "FILE=%FILE:"=%"

if not exist "%FILE%" (
    echo %ESC%[91m❌ 文件不存在%ESC%[0m
    pause
    exit /b
)

REM ================================
REM 1. 提取 hash (借用 pdf2john 提取)
REM ================================
echo.
echo %ESC%[94m[1/3] 提取 PDF 哈希...%ESC%[0m

del "%HASH_FILE%" 2>nul
py -u "%PDF2JOHN%" "%FILE%" > "%HASH_FILE%" 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Content '%HASH_FILE%' | Out-File '%HASH_FILE%.tmp' -Encoding utf8; Move-Item '%HASH_FILE%.tmp' '%HASH_FILE%' -Force"

for %%A in ("%HASH_FILE%") do if %%~zA equ 0 (
    echo %ESC%[91m❌ 哈希提取失败%ESC%[0m
    pause
    exit /b
)
echo %ESC%[92m✔ 提取成功%ESC%[0m

REM =========================
REM 2. 清理 hash（防乱码/换行截断版）
REM =========================
echo.
echo %ESC%[94m[2/3] 清理哈希格式...%ESC%[0m

powershell -NoProfile -Command ^
"$c = Get-Content '%HASH_FILE%' -Raw; ^
if ($c -match '\$pdf\$.*') { $c = $matches[0] }; ^
if ($c -match ':::::') { $c = $c -replace ':::::.*$','' }; ^
$c = $c.Trim(); ^
Set-Content '%HASH_FILE%' $c"

echo %ESC%[92m✔ 清理完成%ESC%[0m
type "%HASH_FILE%"
echo.

REM =========================
REM 3. 自动识别 Hashcat 模式
REM =========================
set "TYPE=pdf"
set "MODE_LIST="
set "LINE="
for /f "usebackq delims=" %%i in ("%HASH_FILE%") do set "LINE=%%i"

echo !LINE! | findstr /C:"$pdf$" >nul
if !errorlevel! equ 0 (
    REM 提取 $pdf$ 后的版本和修订号
    for /f "tokens=2 delims=$*" %%a in ("!LINE!") do set "PDFVERSION=%%a"
    for /f "tokens=1 delims=*" %%v in ("!PDFVERSION!") do set "MAINV=%%v"
    for /f "tokens=2 delims=*" %%r in ("!PDFVERSION!") do set "SUBV=%%r"

    if "!MAINV!"=="4" (
        set "MODE_LIST=10500"
    ) else if "!MAINV!"=="5" (
        if "!SUBV!"=="3" set "MODE_LIST=10600"
        if "!SUBV!"=="6" set "MODE_LIST=10700"
    )
)

if "!MODE_LIST!"=="" (
    echo %ESC%[93m⚠ 无法精确识别 PDF 版本，将遍历全部已知模式%ESC%[0m
    set "MODE_LIST=10500 10600 10700"
)

echo 当前格式: %ESC%[93m!TYPE!%ESC%[0m
echo 待测模式: %ESC%[93m!MODE_LIST!%ESC%[0m

REM =========================
REM 4. 开始多阶段破解
REM =========================
echo.
echo %ESC%[94m[3/3] 开始 Hashcat 多阶段破解...%ESC%[0m
echo.

cd /d "%HASHCAT_DIR%"
set "CRACKED=0"
set "MODE_FOUND="

REM 遍历所有可能的模式
for %%M in (!MODE_LIST!) do (
    call :RUN_STAGES "%%M"
    if "!CRACKED!"=="1" goto show_pwd
)

REM 跑完所有模式都没找到
goto not_found

REM ==========================================
REM 子程序：执行多阶段破解 [隔离避免环境崩溃]
REM ==========================================
:RUN_STAGES
set "M=%~1"
echo.
echo %ESC%[96m=================================================%ESC%[0m
echo %ESC%[96m 🚀 当前尝试 Hash 模式: !M! %ESC%[0m
echo %ESC%[96m=================================================%ESC%[0m

REM ========= 阶段0：检查是否已有缓存 =========
hashcat -m !M! "%HASH_FILE%" --show 2>nul | findstr /R "^\$" >nul
if !errorlevel! equ 0 (
    echo %ESC%[93m提示: 发现该 Hash 已在缓存中，直接提取密码...%ESC%[0m
    set "CRACKED=1"
    set "MODE_FOUND=!M!"
    exit /b
)

REM ========= 阶段1：1-5位纯数字 =========
echo.
echo %ESC%[94m[阶段1] 1-5位纯数字%ESC%[0m
hashcat -m !M! -a 3 "%HASH_FILE%" --increment --increment-min=1 --increment-max=5 ?d?d?d?d?d -w 3
hashcat -m !M! "%HASH_FILE%" --show 2>nul | findstr /R "^\$" >nul
if !errorlevel! equ 0 ( set "CRACKED=1" & set "MODE_FOUND=!M!" & exit /b )

REM ========= 阶段2：6位纯数字 =========
echo.
echo %ESC%[94m[阶段2] 6位纯数字%ESC%[0m
hashcat -m !M! -a 3 "%HASH_FILE%" ?d?d?d?d?d?d -w 3
hashcat -m !M! "%HASH_FILE%" --show 2>nul | findstr /R "^\$" >nul
if !errorlevel! equ 0 ( set "CRACKED=1" & set "MODE_FOUND=!M!" & exit /b )

REM ========= 阶段3：7-10位纯数字 =========
echo.
echo %ESC%[94m[阶段3] 7-10位纯数字%ESC%[0m
hashcat -m !M! -a 3 "%HASH_FILE%" --increment --increment-min=7 --increment-max=10 ?d?d?d?d?d?d?d?d?d?d -w 3
hashcat -m !M! "%HASH_FILE%" --show 2>nul | findstr /R "^\$" >nul
if !errorlevel! equ 0 ( set "CRACKED=1" & set "MODE_FOUND=!M!" & exit /b )

REM ========= 阶段4：3-6位小写字母+数字组合 =========
echo.
echo %ESC%[94m[阶段4] 3-6位小写字母+数字组合%ESC%[0m
REM 修复3：删除 -d 1
hashcat -m !M! -a 3 -1 ?l?d "%HASH_FILE%" --increment --increment-min=3 --increment-max=6 ?1?1?1?1?1?1 -w 3
hashcat -m !M! "%HASH_FILE%" --show 2>nul | findstr /R "^\$" >nul
if !errorlevel! equ 0 ( set "CRACKED=1" & set "MODE_FOUND=!M!" & exit /b )

REM ========= 阶段5：字典+规则终极矩阵 =========
echo.
echo %ESC%[94m[阶段5] 终极矩阵攻击：多字典 × 多规则%ESC%[0m

set "DICTS_DIR=%HASHCAT_DIR%\dicts"
if not exist "%DICTS_DIR%" (
    mkdir "%DICTS_DIR%" 2>nul
    echo %ESC%[93m⚠ 未找到 dicts 文件夹，已自动创建。请放入字典文件。%ESC%[0m
)

for %%D in ("%DICTS_DIR%\*.lst" "%DICTS_DIR%\*.txt") do (
    if exist "%%D" (
        echo.
        echo %ESC%[96m 🎯 当前挂载字典: %%~nxD %ESC%[0m

        REM 修复5：修正规则检测逻辑（先判断是否有规则文件）
        set "HAS_RULE=0"
        if exist "%HASHCAT_DIR%\rules\*.rule" set "HAS_RULE=1"

        if "!HAS_RULE!"=="1" (
            for %%R in ("%HASHCAT_DIR%\rules\*.rule") do (
                if exist "%%R" (
                    echo %ESC%[95m [+] 应用外部规则文件: %%~nxR %ESC%[0m
                    hashcat -m !M! -a 0 -w 3 "%HASH_FILE%" "%%D" -r "%%R"
                    hashcat -m !M! "%HASH_FILE%" --show 2>nul | findstr /R "^\$" >nul
                    if !errorlevel! equ 0 ( set "CRACKED=1" & set "MODE_FOUND=!M!" & exit /b )
                )
            )
        )

        REM 纯字典无变异兜底
        echo %ESC%[93m [+] 进行纯字典爆破 [无变异兜底]... %ESC%[0m
        hashcat -m !M! -a 0 -w 3 "%HASH_FILE%" "%%D"
        hashcat -m !M! "%HASH_FILE%" --show 2>nul | findstr /R "^\$" >nul
        if !errorlevel! equ 0 ( set "CRACKED=1" & set "MODE_FOUND=!M!" & exit /b )
    )
)

exit /b
REM ==========================================

:not_found
echo.
echo %ESC%[91m=========================%ESC%[0m
echo %ESC%[91m❌ 未找到密码（所有破解阶段已结束）%ESC%[0m
echo %ESC%[91m=========================%ESC%[0m
pause
exit /b

REM =========================
REM 输出结果
REM =========================
:show_pwd
setlocal DisableDelayedExpansion

echo.
echo =========================
echo 破解结果
echo =========================

powershell -NoProfile -Command ^
    "$hashcat = '%HASHCAT_DIR%\hashcat.exe'; "^
    "$mode = '%MODE_FOUND%'; "^
    "$hash = '%HASH_FILE%'; "^
    "$output = & \"$hashcat\" -m $mode $hash --show 2>&1; "^
	"$line = $output -split '\r?\n' | Where-Object { $_ -match '\$pdf\$' -and $_ -match ':' }  | Select-Object -First 1; "^
    "if ($line) { "^
    "    $pwd = ($line -split ':',2)[1]; "^
    "    Write-Host '✔ 破解成功！' -ForegroundColor Green; "^
    "    Write-Host ''; "^
    "    Write-Host '密码: ' -NoNewline -ForegroundColor Gray; "^
    "    Write-Host $pwd -ForegroundColor Red "^
    "} else { "^
    "    Write-Host '❌ 未找到密码（所有破解阶段已结束）' -ForegroundColor Red "^
    "}"

echo =========================
endlocal
pause
exit /b