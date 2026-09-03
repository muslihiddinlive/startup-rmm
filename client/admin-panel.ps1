# ============================================================
#  Startup RMM — Admin Panel (GUI)
#  14-kompyuterda ishlatiladi — ega boshqaruv paneli
# ============================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$SERVER = "https://YOUR-APP.onrender.com"   # <-- o'zgartiring
$TOKEN  = "YOUR-SECRET-TOKEN"               # <-- o'zgartiring
$H      = @{ "x-token" = $TOKEN; "Content-Type" = "application/json" }

# ── Yordamchi ─────────────────────────────────────────────────
function sz($w,$h)   { [System.Drawing.Size]::new($w,$h) }
function pt($x,$y)   { [System.Drawing.Point]::new($x,$y) }
function clr($r,$g,$b){ [System.Drawing.Color]::FromArgb($r,$g,$b) }

function api-get($path) {
    try   { Invoke-RestMethod -Uri "$SERVER$path" -Headers $H -TimeoutSec 10 }
    catch { $null }
}
function api-post($path, $body) {
    try   { Invoke-RestMethod -Uri "$SERVER$path" -Method POST -Headers $H -Body ($body | ConvertTo-Json) -TimeoutSec 10 }
    catch { $null }
}

function Get-SelectedIds {
    @($grid.Rows |
      Where-Object { $_.Cells["cid"].Value -and $_.Cells["chk"].Value -eq $true } |
      ForEach-Object { $_.Cells["cid"].Value })
}

function Require-Selection {
    $ids = Get-SelectedIds
    if (-not $ids -or $ids.Count -eq 0) {
        [void][System.Windows.Forms.MessageBox]::Show(
            "Avval kompyuter tanlang!", "Diqqat", 0, 48)
        return $null
    }
    return $ids
}

function Confirm-Action($msg) {
    [System.Windows.Forms.MessageBox]::Show(
        $msg,"Tasdiqlash",4,32) -eq [System.Windows.Forms.DialogResult]::Yes
}

function Do-Command($ids, $type, $data="", $minutes=0) {
    $body = @{ type = $type }
    if ($data)        { $body.data    = $data }
    if ($minutes -gt 0) { $body.minutes = $minutes }
    if ($ids.Count -eq $grid.Rows.Count -and $grid.Rows.Count -gt 0) {
        api-post "/push/all" $body | Out-Null
    } else {
        $ids | ForEach-Object { api-post "/push/$_" $body | Out-Null }
    }
}

function Refresh-Grid {
    $lbl_st.Text = "⏳ Yuklanmoqda..."
    $r = api-get "/clients-list"
    $grid.Rows.Clear()
    if ($r -and $r.clients) {
        $i = 0
        foreach ($c in $r.clients) {
            $i++
            $idx = $grid.Rows.Add()
            $row = $grid.Rows[$idx]
            $row.Cells["chk"].Value  = $false
            $row.Cells["num"].Value  = $i
            $row.Cells["host"].Value = $c.hostname
            $row.Cells["user"].Value = $c.username
            $row.Cells["ip"].Value   = $c.ip
            $row.Cells["seen"].Value = $c.last_seen
            $row.Cells["pend"].Value = $c.pending
            $row.Cells["cid"].Value  = $c.id
        }
        $lbl_st.Text = "✅  Ulangan: $i ta  |  $(Get-Date -Format 'HH:mm:ss')"
    } else {
        $lbl_st.Text = "❌  Server bilan bog'lanib bo'lmadi  |  $(Get-Date -Format 'HH:mm:ss')"
    }
}

# ─────────────────────────────────────────────────────────────
#  ASOSIY FORMA
# ─────────────────────────────────────────────────────────────
$form = New-Object System.Windows.Forms.Form
$form.Text          = "🖥  Startup RMM — Admin Panel"
$form.Size          = sz 1080 660
$form.MinimumSize   = sz 860 520
$form.StartPosition = "CenterScreen"
$form.Font          = New-Object System.Drawing.Font("Segoe UI", 10)
$form.BackColor     = [System.Drawing.Color]::WhiteSmoke

# ── TOP BAR ───────────────────────────────────────────────────
$top = New-Object System.Windows.Forms.Panel
$top.Dock = "Top"; $top.Height = 46
$top.BackColor = clr 24 24 38

$lbl_h = New-Object System.Windows.Forms.Label
$lbl_h.Text      = "  🖥  Startup RMM — Admin Panel"
$lbl_h.Font      = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lbl_h.ForeColor = [System.Drawing.Color]::White
$lbl_h.Location  = pt 0 12; $lbl_h.AutoSize = $true

$btn_rf = New-Object System.Windows.Forms.Button
$btn_rf.Text      = "🔄  Yangilash"
$btn_rf.Size      = sz 120 28
$btn_rf.FlatStyle = "Flat"
$btn_rf.FlatAppearance.BorderColor = clr 80 80 110
$btn_rf.BackColor = clr 48 48 68
$btn_rf.ForeColor = [System.Drawing.Color]::White
$btn_rf.Anchor    = "Top,Right"

$chk_auto = New-Object System.Windows.Forms.CheckBox
$chk_auto.Text      = "Auto (10s)"
$chk_auto.ForeColor = [System.Drawing.Color]::White
$chk_auto.Checked   = $true
$chk_auto.Anchor    = "Top,Right"

$top.Controls.AddRange(@($lbl_h, $btn_rf, $chk_auto))

# ── STATUS BAR ────────────────────────────────────────────────
$sb     = New-Object System.Windows.Forms.StatusStrip
$lbl_st = New-Object System.Windows.Forms.ToolStripStatusLabel
$lbl_st.Text      = "Tayyorlanmoqda..."
$lbl_st.Spring    = $true
$lbl_st.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$sb.Items.Add($lbl_st) | Out-Null

# ── SPLIT (grid | amallar) ────────────────────────────────────
$split = New-Object System.Windows.Forms.SplitContainer
$split.Dock             = "Fill"
$split.SplitterDistance = 650
$split.Panel2MinSize    = 278

# ─────────────────────────────────────────────────────────────
#  GRID
# ─────────────────────────────────────────────────────────────
$grid = New-Object System.Windows.Forms.DataGridView
$grid.Dock                    = "Fill"
$grid.AllowUserToAddRows      = $false
$grid.AllowUserToDeleteRows   = $false
$grid.SelectionMode           = "FullRowSelect"
$grid.MultiSelect             = $false
$grid.RowHeadersVisible       = $false
$grid.BorderStyle             = "None"
$grid.BackgroundColor         = [System.Drawing.Color]::White
$grid.GridColor               = clr 220 220 232
$grid.ColumnHeadersHeight     = 36
$grid.RowTemplate.Height      = 32
$grid.DefaultCellStyle.SelectionBackColor = clr 210 225 255
$grid.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::Black
$grid.AlternatingRowsDefaultCellStyle.BackColor = clr 248 249 255
$grid.ColumnHeadersDefaultCellStyle.Font =
    New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

# Ustunlar
$colDefs = @(
    @{ n="chk"; h="✓";              w=36;  t="chk" },
    @{ n="num"; h="#";              w=36;  t="txt" },
    @{ n="host";h="Kompyuter";      w=170; t="txt" },
    @{ n="user";h="Foydalanuvchi";  w=145; t="txt" },
    @{ n="ip";  h="IP";             w=125; t="txt" },
    @{ n="seen";h="Oxirgi";         w=115; t="txt" },
    @{ n="pend";h="📋";             w=42;  t="txt" },
    @{ n="cid"; h="";               w=0;   t="hid" }
)
foreach ($d in $colDefs) {
    $col = if ($d.t -eq "chk") {
        New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    } else {
        $c = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $c.ReadOnly = $true; $c
    }
    $col.Name = $d.n; $col.HeaderText = $d.h; $col.Width = $d.w
    if ($d.t -eq "hid") { $col.Visible = $false }
    $grid.Columns.Add($col) | Out-Null
}

# Qator bosilganda checkbox ni toggle qilish
$grid.add_CellClick({
    param($s, $e)
    if ($e.RowIndex -ge 0 -and $e.ColumnIndex -ne $grid.Columns["chk"].Index) {
        $cell = $grid.Rows[$e.RowIndex].Cells["chk"]
        $cell.Value = -not [bool]$cell.Value
        $grid.RefreshEdit()
    }
})

$split.Panel1.Controls.Add($grid)

# ─────────────────────────────────────────────────────────────
#  AMALLAR PANELI (o'ngdagi)
# ─────────────────────────────────────────────────────────────
$flow = New-Object System.Windows.Forms.FlowLayoutPanel
$flow.Dock          = "Fill"
$flow.FlowDirection = "TopDown"
$flow.WrapContents  = $false
$flow.AutoScroll    = $true
$flow.Padding       = New-Object System.Windows.Forms.Padding(8, 8, 8, 8)
$split.Panel2.Controls.Add($flow)

# ── Yordamchi funksiyalar ─────────────────────────────────────
function grp($title, $h) {
    $g = New-Object System.Windows.Forms.GroupBox
    $g.Text   = $title
    $g.Size   = sz 258 $h
    $g.Font   = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $g.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 5)
    $flow.Controls.Add($g)
    return $g
}

function mkbtn($parent, $text, $x, $y, $w=122, $h=28) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text      = $text
    $b.Location  = pt $x $y
    $b.Size      = sz $w $h
    $b.FlatStyle = "Flat"
    $b.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
    $parent.Controls.Add($b)
    return $b
}

function mktbx($parent, $x, $y, $w, $ph="") {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location        = pt $x $y
    $t.Size            = sz $w 24
    $t.PlaceholderText = $ph
    $parent.Controls.Add($t)
    return $t
}

function mklbl($parent, $text, $x, $y) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text     = $text
    $l.Location = pt $x $y
    $l.AutoSize = $true
    $parent.Controls.Add($l)
}

# ── 1. TANLASH ───────────────────────────────────────────────
$g1 = grp "Tanlash" 64
$b_all  = mkbtn $g1 "☑  Hammasini"  8 20 122 28
$b_none = mkbtn $g1 "☐  Bekor"    134 20 116 28

$b_all.add_Click({
    foreach ($r in $grid.Rows) { $r.Cells["chk"].Value = $true }
    $grid.RefreshEdit()
})
$b_none.add_Click({
    foreach ($r in $grid.Rows) { $r.Cells["chk"].Value = $false }
    $grid.RefreshEdit()
})

# ── 2. QUVVAT ────────────────────────────────────────────────
$g2 = grp "Quvvat" 106
$b_off = mkbtn $g2 "🔴  O'chirish"  8 20 122 28
$b_slp = mkbtn $g2 "😴  Uxlatish" 134 20 116 28
$b_rst = mkbtn $g2 "🔄  Qayta yuklash" 8 54 242 28

$b_off.add_Click({
    $ids = Require-Selection; if (-not $ids) { return }
    if (Confirm-Action "$($ids.Count) ta kompyuter o'chirilsinmi?") {
        Do-Command $ids "shutdown"
        $lbl_st.Text = "🔴  O'chirish yuborildi → $($ids.Count) ta"
    }
})
$b_slp.add_Click({
    $ids = Require-Selection; if (-not $ids) { return }
    Do-Command $ids "sleep"
    $lbl_st.Text = "😴  Uxlatish → $($ids.Count) ta"
})
$b_rst.add_Click({
    $ids = Require-Selection; if (-not $ids) { return }
    if (Confirm-Action "$($ids.Count) ta kompyuter restart qilinsinmi?") {
        Do-Command $ids "restart"
        $lbl_st.Text = "🔄  Restart → $($ids.Count) ta"
    }
})

# ── 3. BLOKLASH ──────────────────────────────────────────────
$g3 = grp "Bloklash" 104
mklbl $g3 "Daqiqa:" 8 25
$num_m = New-Object System.Windows.Forms.NumericUpDown
$num_m.Location = pt 72 22; $num_m.Size = sz 72 24
$num_m.Minimum = 0; $num_m.Maximum = 480; $num_m.Value = 0
$g3.Controls.Add($num_m)
mklbl $g3 "(0 = men ochguncha)" 152 25

$b_blk  = mkbtn $g3 "🔒  Bloklash"   8 56 122 28
$b_ublk = mkbtn $g3 "🔓  Blok ochish" 134 56 116 28

$b_blk.add_Click({
    $ids = Require-Selection; if (-not $ids) { return }
    $m   = [int]$num_m.Value
    Do-Command $ids "block" "" $m
    $tag = if ($m -gt 0) { "$m daqiqa" } else { "doimiy" }
    $lbl_st.Text = "🔒  Bloklash ($tag) → $($ids.Count) ta"
})
$b_ublk.add_Click({
    $ids = Require-Selection; if (-not $ids) { return }
    Do-Command $ids "unblock"
    $lbl_st.Text = "🔓  Blok ochildi → $($ids.Count) ta"
})

# ── 4. EKRAN ─────────────────────────────────────────────────
$g4      = grp "Ekran" 150
$txt_msg = mktbx $g4 8 22 242 "Xabar matni..."
$b_msg   = mkbtn $g4 "💬  Xabar chiqarish" 8 52 242 28

$txt_url = mktbx $g4 8 92 242 "Rasm URL (https://...)"
$b_img   = mkbtn $g4 "🖼  Rasm ko'rsatish" 8 122 242 28

$b_msg.add_Click({
    $ids = Require-Selection; if (-not $ids) { return }
    $t = $txt_msg.Text.Trim()
    if (-not $t) { [void][System.Windows.Forms.MessageBox]::Show("Matn kiriting!"); return }
    Do-Command $ids "show" $t
    $lbl_st.Text = "💬  Xabar → $($ids.Count) ta"
})
$b_img.add_Click({
    $ids = Require-Selection; if (-not $ids) { return }
    $u = $txt_url.Text.Trim()
    if (-not $u) { [void][System.Windows.Forms.MessageBox]::Show("URL kiriting!"); return }
    Do-Command $ids "img" $u
    $lbl_st.Text = "🖼  Rasm → $($ids.Count) ta"
})

# ── 5. CMD ───────────────────────────────────────────────────
$g5      = grp "CMD" 90
$txt_cmd = mktbx $g5 8 22 242 "ipconfig, tasklist, netstat..."
$b_cmd   = mkbtn $g5 "▶  Bajar  (natija Telegramga keladi)" 8 54 242 28

$b_cmd.add_Click({
    $ids = Require-Selection; if (-not $ids) { return }
    $c = $txt_cmd.Text.Trim()
    if (-not $c) { [void][System.Windows.Forms.MessageBox]::Show("Buyruq kiriting!"); return }
    Do-Command $ids "cmd" $c
    $lbl_st.Text = "▶  CMD → $($ids.Count) ta  |  natija Telegramga keladi"
})

# ── TOP BAR o'lchamga qarab joylashtirish ─────────────────────
$form.add_Resize({
    $btn_rf.Location   = pt ($form.ClientSize.Width - 252) 9
    $chk_auto.Location = pt ($form.ClientSize.Width - 128) 14
})
$btn_rf.add_Click({ Refresh-Grid })

# ── AUTO YANGILANISH ──────────────────────────────────────────
$tmr = New-Object System.Windows.Forms.Timer
$tmr.Interval = 10000
$tmr.add_Tick({ if ($chk_auto.Checked) { Refresh-Grid } })
$tmr.Start()

# ── ISHGA TUSHIRISH ───────────────────────────────────────────
$form.Controls.AddRange(@($top, $split, $sb))
$form.add_Shown({ Refresh-Grid })
$form.add_FormClosed({ $tmr.Stop() })
[System.Windows.Forms.Application]::Run($form)
