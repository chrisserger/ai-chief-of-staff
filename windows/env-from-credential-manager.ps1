# env-from-credential-manager.ps1 — Pull secrets from Windows Credential Manager into .env
#
# This is the Windows equivalent of macOS Keychain for storing API keys securely.
# Optional — you can also just edit .env directly.
#
# STORING SECRETS (run these once):
#   cmdkey /generic:aicos_PINECONE_API_KEY /user:aicos /pass:your-key-here
#   cmdkey /generic:aicos_GEMINI_API_KEY /user:aicos /pass:your-key-here
#
# USAGE (generates/updates .env):
#   powershell -ExecutionPolicy Bypass -File windows\env-from-credential-manager.ps1
#
# The script reads all credentials with the "aicos_" prefix and writes them as
# KEY=VALUE lines in .env. Existing values in .env are NOT overwritten.

param(
    [string]$Prefix = "aicos_",
    [string]$EnvFile = $null
)

$ErrorActionPreference = "Stop"

# Determine .env path
if (-not $EnvFile) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $repoPath = Split-Path -Parent $scriptDir
    $EnvFile = Join-Path $repoPath ".env"
}

Write-Host "AI Chief of Staff — Credential Manager to .env" -ForegroundColor Cyan
Write-Host "================================================"
Write-Host ""

# Read existing .env if it exists
$existingKeys = @{}
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match "^([A-Z_]+)=") {
            $existingKeys[$Matches[1]] = $true
        }
    }
}

# Query credentials using cmdkey
$output = cmdkey /list 2>&1 | Out-String
$credentials = @()

# Parse cmdkey output for our prefix
$lines = $output -split "`n"
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "Target:\s*${Prefix}(\w+)") {
        $keyName = $Matches[1]
        $credentials += $keyName
    }
}

if ($credentials.Count -eq 0) {
    Write-Host "  No credentials found with prefix '$Prefix'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  To store secrets, run:"
    Write-Host "    cmdkey /generic:${Prefix}PINECONE_API_KEY /user:aicos /pass:your-key"
    Write-Host "    cmdkey /generic:${Prefix}GEMINI_API_KEY /user:aicos /pass:your-key"
    exit 0
}

Write-Host "  Found $($credentials.Count) credential(s) with prefix '$Prefix'"
Write-Host ""

$written = 0
$skipped = 0
$newLines = @()

# Load Windows Credential API via P/Invoke (once, before the loop)
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class CredManager {
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool CredRead(string target, int type, int flags, out IntPtr credential);
    [DllImport("advapi32.dll")]
    public static extern void CredFree(IntPtr credential);
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDENTIAL {
        public int Flags;
        public int Type;
        public string TargetName;
        public string Comment;
        public long LastWritten;
        public int CredentialBlobSize;
        public IntPtr CredentialBlob;
        public int Persist;
        public int AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }
    public static string GetPassword(string target) {
        IntPtr credPtr;
        if (!CredRead(target, 1, 0, out credPtr)) return null;
        var cred = (CREDENTIAL)Marshal.PtrToStructure(credPtr, typeof(CREDENTIAL));
        string pass = Marshal.PtrToStringUni(cred.CredentialBlob, cred.CredentialBlobSize / 2);
        CredFree(credPtr);
        return pass;
    }
}
"@ -ErrorAction SilentlyContinue

foreach ($key in $credentials) {
    if ($existingKeys.ContainsKey($key)) {
        Write-Host "  SKIP  $key (already in .env)" -ForegroundColor DarkGray
        $skipped++
        continue
    }

    try {
        $password = [CredManager]::GetPassword("${Prefix}${key}")
        if ($password) {
            $newLines += "${key}=${password}"
            Write-Host "  ADD   $key" -ForegroundColor Green
            $written++
        } else {
            Write-Host "  FAIL  $key (could not read value)" -ForegroundColor Red
        }
    } catch {
        Write-Host "  FAIL  $key ($($_.Exception.Message))" -ForegroundColor Red
    }
}

# Append new lines to .env
if ($newLines.Count -gt 0) {
    if (-not (Test-Path $EnvFile)) {
        "# AI Chief of Staff — environment variables" | Out-File -FilePath $EnvFile -Encoding utf8
        "" | Out-File -FilePath $EnvFile -Append -Encoding utf8
    }
    $newLines | Out-File -FilePath $EnvFile -Append -Encoding utf8
}

Write-Host ""
Write-Host "  Written: $written | Skipped: $skipped" -ForegroundColor Cyan
Write-Host "  File: $EnvFile"
