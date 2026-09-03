# ============================================================
#  Startup RMM — Client v2
#  Yangiliklar: shutdown / sleep / restart / block / unblock
# ============================================================

$SERVER   = "https://YOUR-APP.onrender.com"   # <-- o'zgartiring
$TOKEN    = "YOUR-SECRET-TOKEN"               # <-- o'zgartiring
$INTERVAL = 5   # soniya

# ── Client ID ────────────────────────────────────────────────
$RMM_DIR   = "$env:APPDATA\rmm"
$ID_FILE   = "$RMM_DIR\client_id.txt"
$BLOCK_FLAG = "$RMM_DIR\block.flag"   # mavjud = bloklangan

New-Item -ItemType Directory -Force -Path $RMM_DIR | Out-Null

if (Test-Path $ID_FILE) {
    $CLIENT_ID = (Get-Content $ID_FILE).Trim()
} else {
    $CLIENT_ID = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
    $CLIENT_ID | Set-Content $ID_FILE
}

$HEADERS = @{
    "x-token"      = $TOKEN
    "Content-Type" = "application/json"
}

# ─────────────────────────────────────────────────────────────
#  YORDAMCHI FUNKSIYALAR
# ─────────────────────────────────────────────────────────────

function Register-Client {
    try {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
               Where-Object { $_.IPAddress -notmatch "^127\.|^169\." } |
               Select-Object -First 1).IPAddress
        $body = @{
            client_id = $CLIENT_ID
            hostname  = $env:COMPUTERNAME
            username  = $env:USERNAME
            ip        = if ($ip) { $ip } else { "unknown" }
        } | ConvertTo-Json
        Invoke-RestMethod -Uri "$SERVER/register" -Method POST -Headers $HEADERS -Body $body -TimeoutSec 10
    } catch { }
}

function Send-Result($command, $output, $success) {
    $body = @{
        command = $command
        output  = if ($output.Length -gt 3000) { $output.Substring(0,3000) + "..." } else { $output }
        success = $success
    } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri "$SERVER/result/$CLIENT_ID" -Method POST -Headers $HEADERS -Body $body -TimeoutSec 10
    } catch { }
}

function Invoke-Cmd($command) {
    try {
        $out = (cmd.exe /c "$command" 2>&1) | Out-String
        return @{ output = $out.Trim(); success = $true }
    } catch {
        return @{ output = $_.Exception.Message; success = $false }
    }
}

# ─────────────────────────────────────────────────────────────
#  EKRAN FUNKSIYALARI (async runspace)
# ─────────────────────────────────────────────────────────────

function Show-MessageAsync($text) {
    $rs = [runspacefactory]::CreateRunspace(); $rs.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddScript({
        param($msg)
        Add-Type -AssemblyName System.Windows.Forms
        [void][System.Windows.Forms.MessageBox]::Show(
            $msg, "⚠️ Admin Xabar",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }).AddParameter("msg", $text)
    [void]$ps.BeginInvoke()
}

function Show-ImageAsync($url) {
    $rs = [runspacefactory]::CreateRunspace(); $rs.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddScript({
        param($imgUrl)
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        try {
            $tmp = "$env:TEMP\rmm_img_$(Get-Random).jpg"
            Invoke-WebRequest -Uri $imgUrl -OutFile $tmp -UseBasicParsing
            $form = New-Object System.Windows.Forms.Form
            $form.Text = "Admin Rasm  [ESC — yopish]"
            $form.TopMost = $true
            $form.WindowState = [System.Windows.Forms.FormWindowState]::Maximized
            $form.KeyPreview = $true
            $pb = New-Object System.Windows.Forms.PictureBox
            $pb.Dock = [System.Windows.Forms.DockStyle]::Fill
            $pb.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
            $pb.Image = [System.Drawing.Image]::FromFile($tmp)
            $form.Controls.Add($pb)
            $form.add_KeyDown({ param($s,$e); if ($e.KeyCode -in @('Escape','Return')) { $s.Close() } })
            [void]$form.ShowDialog()
            $pb.Image.Dispose()
            Remove-Item $tmp -ErrorAction SilentlyContinue
        } catch {
            [void][System.Windows.Forms.MessageBox]::Show("Rasm yuklanmadi: $imgUrl")
        }
    }).AddParameter("imgUrl", $url)
    [void]$ps.BeginInvoke()
}

# ─────────────────────────────────────────────────────────────
#  BLOKLASH EKRANI
# ─────────────────────────────────────────────────────────────

function Show-BlockScreen($minutes) {
    # Flag fayl: mavjud = bloklangan, yo'q = ochish
    $expiry = if ($minutes -gt 0) {
        [datetime]::Now.AddMinutes($minutes).ToString("o")
    } else { "permanent" }
    $expiry | Set-Content $BLOCK_FLAG

    $flagPath = $BLOCK_FLAG

    $rs = [runspacefactory]::CreateRunspace(); $rs.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddScript({
        param($flagPath, $minutes)
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $script:canClose = $false
        $expiryDt = if ($minutes -gt 0) { [datetime]::Now.AddMinutes($minutes) } else { $null }

        # ── Form ──────────────────────────────────────────────
        $form = New-Object System.Windows.Forms.Form
        $form.TopMost         = $true
        $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
        $form.WindowState     = [System.Windows.Forms.FormWindowState]::Maximized
        $form.BackColor       = [System.Drawing.Color]::FromArgb(12, 12, 20)
        $form.KeyPreview      = $true

        # Barcha tugmachalarni bloklash
        $form.add_KeyDown({ param($s,$e)
            $e.SuppressKeyPress = $true
            $e.Handled = $true
        })
        # Yopishni bloklash
        $form.add_FormClosing({ param($s,$e)
            if (-not $script:canClose) { $e.Cancel = $true }
        })

        # ── Labellar ──────────────────────────────────────────
        $lblLock = New-Object System.Windows.Forms.Label
        $lblLock.Text      = "BLOKLANGAN"
        $lblLock.Font      = New-Object System.Drawing.Font("Segoe UI", 52, [System.Drawing.FontStyle]::Bold)
        $lblLock.ForeColor = [System.Drawing.Color]::FromArgb(255, 80, 80)
        $lblLock.AutoSize  = $true

        $lblSub = New-Object System.Windows.Forms.Label
        $lblSub.Font      = New-Object System.Drawing.Font("Segoe UI", 18)
        $lblSub.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 190)
        $lblSub.AutoSize  = $true
        $lblSub.Text      = if ($minutes -gt 0) { "$minutes daqiqaga bloklandi" } else { "Admin ochguncha blok davom etadi" }

        $lblTimer = New-Object System.Windows.Forms.Label
        $lblTimer.Font      = New-Object System.Drawing.Font("Consolas", 36, [System.Drawing.FontStyle]::Bold)
        $lblTimer.ForeColor = [System.Drawing.Color]::FromArgb(60, 160, 255)
        $lblTimer.AutoSize  = $true
        $lblTimer.Visible   = ($minutes -gt 0)
        $lblTimer.Text      = "00:00"

        $form.Controls.AddRange(@($lblLock, $lblSub, $lblTimer))

        function Reposition {
            $cx = [int]($form.ClientSize.Width  / 2)
            $cy = [int]($form.ClientSize.Height / 2)
            $lblLock.Location  = [System.Drawing.Point]::new($cx - [int]($lblLock.Width/2),  $cy - 110)
            $lblSub.Location   = [System.Drawing.Point]::new($cx - [int]($lblSub.Width/2),   $cy + 20)
            $lblTimer.Location = [System.Drawing.Point]::new($cx - [int]($lblTimer.Width/2), $cy + 75)
        }

        $form.add_Shown({  Reposition })
        $form.add_Resize({ Reposition })

        # ── Tekshirish (1 soniya) ──────────────────────────────
        $t = New-Object System.Windows.Forms.Timer
        $t.Interval = 1000
        $t.add_Tick({
            # Flag o'chiriladimi? → unblock
            if (-not (Test-Path $flagPath)) {
                $t.Stop(); $script:canClose = $true; $form.Close(); return
            }
            # Vaqt tugadimi?
            if ($null -ne $expiryDt) {
                $rem = $expiryDt - [datetime]::Now
                if ($rem.TotalSeconds -le 0) {
                    Remove-Item $flagPath -ErrorAction SilentlyContinue
                    $t.Stop(); $script:canClose = $true; $form.Close(); return
                }
                $lblTimer.Text = "{0:D2}:{1:D2}" -f [int]$rem.TotalMinutes, $rem.Seconds
                Reposition
            }
        })
        $t.Start()
        [void]$form.ShowDialog()
        $t.Stop()

    }).AddParameter("flagPath", $flagPath).AddParameter("minutes", $minutes)
    [void]$ps.BeginInvoke()
}

function Remove-Block {
    Remove-Item $BLOCK_FLAG -ErrorAction SilentlyContinue
}

# ─────────────────────────────────────────────────────────────
#  ASOSIY LOOP
# ─────────────────────────────────────────────────────────────

Register-Client
$fails = 0

while ($true) {
    try {
        $resp = Invoke-RestMethod -Uri "$SERVER/poll/$CLIENT_ID" -Method GET -Headers $HEADERS -TimeoutSec 10
        $fails = 0

        if ($null -ne $resp.command) {
            $type = $resp.command.type
            $data = $resp.command.data

            switch ($type) {

                "cmd" {
                    $r = Invoke-Cmd $data
                    Send-Result $data $r.output $r.success
                }

                "show" {
                    Show-MessageAsync $data
                    Send-Result "show" "✅ Xabar ko'rsatildi" $true
                }

                "img" {
                    Show-ImageAsync $data
                    Send-Result "img" "✅ Rasm ko'rsatildi" $true
                }

                "shutdown" {
                    Send-Result "shutdown" "✅ O'chirilmoqda..." $true
                    Start-Sleep -Seconds 2
                    shutdown /s /t 0
                }

                "sleep" {
                    Send-Result "sleep" "✅ Uxlamoqda..." $true
                    Start-Sleep -Seconds 2
                    Add-Type -AssemblyName System.Windows.Forms
                    [System.Windows.Forms.Application]::SetSuspendState('Suspend', $false, $false) | Out-Null
                }

                "restart" {
                    Send-Result "restart" "✅ Qayta yuklanmoqda..." $true
                    Start-Sleep -Seconds 2
                    shutdown /r /t 0
                }

                "block" {
                    $mins = if ($resp.command.minutes) { [int]$resp.command.minutes } else { 0 }
                    $label = if ($mins -gt 0) { "$mins daqiqa blok" } else { "Doimiy blok" }
                    Show-BlockScreen $mins
                    Send-Result "block" "✅ $label boshlandi" $true
                }

                "unblock" {
                    Remove-Block
                    Send-Result "unblock" "✅ Blok ochildi" $true
                }
            }
        }
    } catch {
        $fails++
        if ($fails -ge 3) {
            $fails = 0
            Start-Sleep -Seconds 15
            Register-Client
        }
    }

    Start-Sleep -Seconds $INTERVAL
}
