$LogFile = "$env:TEMP\rdp_setup_log.txt"
$RdpPort = 3389
$RdpWrapperVer = "1.6.2"
$RdpWrapperUrl = "https://github.com/stascorp/rdpwrap/releases/download/v$RdpWrapperVer/RDPWInst-v$RdpWrapperVer.msi"
$RdpWrapperInstaller = "$env:TEMP\RDPWInst.msi"
$RdcManUrl = "https://file.lowendviet.com/RDCMan/RemoteDesktopConnectionManager2.7.msi"
$RdcManMsi = "$env:TEMP\RemoteDesktopConnectionManager2.7.msi"
$RdcManExe = "${env:ProgramFiles(x86)}\Remote Desktop Connection Manager\RDCMan.exe"
if (-not (Test-Path $RdcManExe)) {
    $RdcManExe = "C:\Program Files\Remote Desktop Connection Manager\RDCMan.exe"
}
$CurrentUser = "$env:USERNAME"

function Log {
    param([string]$msg)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $msg" | Out-File -FilePath $LogFile -Append -Encoding utf8
    Write-Host $msg
}

function Ensure-Admin {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("Administrator")) {
        Write-Host "⚠️ Script cần chạy với quyền Admin. Thoát..."
        exit 1
    }
}

Ensure-Admin
Log "`n===== Bắt đầu cấu hình RDP ====="

# Bật RDP nếu chưa
try {
    $status = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections
    if ($status.fDenyTSConnections -ne 0) {
        Log "Bật Remote Desktop và cấu hình firewall..."
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -Value 0
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
        Set-Service -Name TermService -StartupType Automatic
        Start-Service -Name TermService -ErrorAction SilentlyContinue
        Log "✅ Đã bật RDP và cấu hình dịch vụ."
    } else {
        Log "✅ RDP đã được bật sẵn."
    }
} catch {
    Log "❌ Lỗi bật RDP: $_"
    exit 1
}

# Tải RDP Wrapper nếu cần
if (-Not (Test-Path $RdpWrapperInstaller)) {
    try {
        Log "🔽 Đang tải RDP Wrapper..."
        Invoke-WebRequest -Uri $RdpWrapperUrl -OutFile $RdpWrapperInstaller -UseBasicParsing
        Log "✅ Tải xong RDP Wrapper."
    } catch {
        Log "❌ Lỗi tải RDP Wrapper: $_"
        exit 1
    }
} else {
    Log "🗂️ Đã có file RDP Wrapper installer."
}

# Cài đặt RDP Wrapper
try {
    Log "⚙️ Đang cài RDP Wrapper..."
    $res = Start-Process msiexec.exe -ArgumentList "/i `"$RdpWrapperInstaller`" /quiet /norestart" -Wait -PassThru
    if ($res.ExitCode -eq 0) {
        Log "✅ Cài RDP Wrapper thành công."
    } else {
        Log "❌ Lỗi cài RDP Wrapper. ExitCode=$($res.ExitCode)"
    }
} catch {
    Log "❌ Lỗi khi cài đặt RDP Wrapper: $_"
}

# Kiểm tra trạng thái RDP Wrapper
$iniPath = "C:\Program Files\RDP Wrapper\rdpwrap.ini"
if (Test-Path $iniPath) {
    $iniContent = Get-Content $iniPath -Raw
    if ($iniContent -match "Listener state.*Listening") {
        Log "✅ RDP Wrapper đang hoạt động tốt (Listening)."
    } else {
        Log "⚠️ RDP Wrapper chưa hoạt động đúng. Vui lòng kiểm tra cấu hình INI."
    }
} else {
    Log "❌ Không tìm thấy rdpwrap.ini"
}

# Thêm user hiện tại vào nhóm Remote Desktop Users
try {
    if (-not (Get-LocalGroupMember -Group "Remote Desktop Users" | Where-Object { $_.Name -like "*\$CurrentUser" })) {
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $CurrentUser
        Log "✅ Đã thêm user $CurrentUser vào nhóm Remote Desktop Users."
    } else {
        Log "👤 User $CurrentUser đã nằm trong nhóm Remote Desktop Users."
    }
} catch {
    Log "❌ Lỗi khi thêm user vào nhóm: $_"
}

# Tải RDCMan nếu cần
if (-not (Test-Path $RdcManMsi)) {
    try {
        Log "🔽 Đang tải RDCMan..."
        Invoke-WebRequest -Uri $RdcManUrl -OutFile $RdcManMsi -UseBasicParsing
        Log "✅ Đã tải RDCMan."
    } catch {
        Log "❌ Lỗi khi tải RDCMan: $_"
    }
} else {
    Log "🗂️ Đã có file RDCMan installer."
}

# Cài đặt RDCMan
try {
    $res = Start-Process msiexec.exe -ArgumentList "/i `"$RdcManMsi`" /quiet /norestart" -Wait -PassThru
    if ($res.ExitCode -eq 0) {
        Log "✅ Cài đặt RDCMan thành công."
    } else {
        Log "❌ Lỗi cài đặt RDCMan. ExitCode=$($res.ExitCode)"
    }
} catch {
    Log "❌ Lỗi khi cài RDCMan: $_"
}

# Mở RDCMan nếu có
if (Test-Path $RdcManExe) {
    Log "🚀 Mở RDCMan..."
    Start-Process $RdcManExe
} else {
    Log "❌ Không tìm thấy RDCMan.exe"
}

Log "===== ✅ Kết thúc cấu hình RDP ====="
Write-Host "`n📝 Xem log tại: $LogFile"
