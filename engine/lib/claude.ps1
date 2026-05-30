# lib/claude.ps1 — wrapper gọi claude (-Mock để test offline).
# Implement Session 1.1.

Set-StrictMode -Version Latest

# Bộ đếm số lần gọi mock theo agent — dùng cho kịch bản router xác định (Session 2.1).
# Khởi tạo lúc dot-source → mỗi process run.ps1 bắt đầu sạch (test ở process riêng).
$script:MockAgentCalls = @{}

function Invoke-Claude {
    <#
    .SYNOPSIS
        Gọi 1 agent: nạp $SystemPromptFile làm system prompt, đẩy $Prompt làm user input,
        trả về text output của model.
    .DESCRIPTION
        -Mock: không gọi model thật. Trả output xác định (deterministic) chỉ phụ thuộc
        agent + prompt → để Phase 1–3 test offline, không đốt token.
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$Prompt,
        [Parameter(Mandatory, Position = 1)][string]$SystemPromptFile,
        [switch]$Mock,
        [string]$Model,
        [string]$AllowedTools,    # vd "Write Edit Bash(mkdir:*)" — pre-grant quyền theo vai (headless)
        [string]$PermissionMode,  # vd "acceptEdits" — tự duyệt thay vì prompt tương tác
        [string]$WorkingDir,      # cwd cho claude subprocess (vd sandbox dir) → file-write của agent
                                  # rơi vào đúng project (Phase 5.3). Vắng = giữ cwd hiện tại.
        [string]$NodeId,          # id node đang chạy (A-02, C.8): cho ENGINE_MOCK_ROUTER keyed-by-node.
                                  # Vắng = chỉ keyed-by-agent (tương thích cũ). Mock-only; real bỏ qua.
        [string]$RunDir = ''      # A-08 (C.10): thư mục run để ghi stderr real-mode riêng (claude.stderr.log).
    )

    if (-not (Test-Path -LiteralPath $SystemPromptFile)) {
        throw "Invoke-Claude: system prompt file không tồn tại: $SystemPromptFile"
    }

    $agent = [System.IO.Path]::GetFileNameWithoutExtension($SystemPromptFile)

    if ($Mock) {
        # Hook test lỗi offline (Session 4.1): nếu $env:ENGINE_MOCK_FAIL khớp tên agent,
        # ném lỗi xác định để mô phỏng agent/claude fail mà không cần gọi model thật.
        if ($env:ENGINE_MOCK_FAIL -and $agent -eq $env:ENGINE_MOCK_FAIL) {
            throw "Invoke-Claude(mock): mô phỏng agent fail cho '$agent' (ENGINE_MOCK_FAIL)."
        }
        # Hook kịch bản router xác định (Session 2.1): nhãn theo VÒNG, offline.
        # Format 1-router:   $env:ENGINE_MOCK_ROUTER = "<key>:label1,label2,..."
        # Format đa-router (Session 0-C.1): nhiều spec ngăn bởi ';'
        #   $env:ENGINE_MOCK_ROUTER = "<keyA>:l1,l2;<keyB>:l3,l4"
        #   → mỗi router steer độc lập (p-brain có nhiều router trên cùng path).
        #   Thay đổi testing-only, additive: 1 spec (không ';') vẫn chạy y như cũ.
        #   Lần gọi mock thứ i của <key> → trả labelᵢ; cạn danh sách → giữ nhãn cuối.
        #   "fail,fail,pass" → loop 2 vòng rồi thoát; "fail" → luôn fail → chạm max_steps.
        # Router agent in đúng 1 dòng nhãn (engine khớp dòng cuối với `when`).
        #
        # A-02 (C.8): <key> match theo NODE id TRƯỚC (nếu -NodeId truyền), rồi fall-back AGENT name.
        #   → 2 node router CHUNG 1 agent file dùng spec keyed-by-node để steer ĐỘC LẬP (counter tách
        #   theo key đã match). Spec keyed-by-agent CŨ chạy y nguyên (NodeId không match → rơi agent-pass).
        #   Bộ đếm keyed theo $matchKey đã match → keyed-by-node và keyed-by-agent không share counter.
        if ($env:ENGINE_MOCK_ROUTER) {
            $entries = @($env:ENGINE_MOCK_ROUTER -split ';' | Where-Object { $_.Trim() })
            foreach ($matchKey in @($NodeId, $agent)) {
                if ([string]::IsNullOrWhiteSpace($matchKey)) { continue }
                foreach ($entry in $entries) {
                    $spec = $entry -split ':', 2
                    if ($spec.Count -eq 2 -and $spec[0].Trim() -eq $matchKey) {
                        $labels = @($spec[1] -split ',' | ForEach-Object { $_.Trim() })
                        $n = if ($script:MockAgentCalls.ContainsKey($matchKey)) { $script:MockAgentCalls[$matchKey] } else { 0 }
                        $script:MockAgentCalls[$matchKey] = $n + 1
                        $idx = [Math]::Min($n, $labels.Count - 1)
                        return $labels[$idx]
                    }
                }
            }
        }
        # Output xác định: tiền tố agent + nguyên văn prompt. Cùng input → cùng output.
        return "[MOCK:$agent]`n$Prompt"
    }

    # --- Real mode: gọi claude CLI (chỉ chạy khi không -Mock; không test ở Session 1.1) ---
    # A-09 (C.9): dùng $claudeArgs thay $args — KHÔNG đè biến tự động $args của PowerShell.
    $claudeArgs = @('-p', '--system-prompt-file', $SystemPromptFile, '--output-format', 'json')
    if ($Model)          { $claudeArgs += @('--model', $Model) }
    if ($AllowedTools)   { $claudeArgs += @('--allowedTools', $AllowedTools) }
    if ($PermissionMode) { $claudeArgs += @('--permission-mode', $PermissionMode) }

    # A-08 (C.10): tách stderr KHỎI $raw để cảnh báo CLI (deprecation, v.v.) không lẫn vào
    # JSON stdout → ConvertFrom-Json không còn fail vì stderr. stderr ghi ra FILE riêng;
    # $raw = stdout-only. errFile tính ABSOLUTE TRƯỚC Push-Location (cwd có thể đổi sang sandbox).
    $persistErr = ($RunDir -and (Test-Path -LiteralPath $RunDir))
    $errFile = if ($persistErr) {
        Join-Path ((Resolve-Path -LiteralPath $RunDir).Path) 'claude.stderr.log'
    } else {
        Join-Path ([IO.Path]::GetTempPath()) ("claude-err-" + [guid]::NewGuid().ToString('N') + '.log')
    }

    # cwd = $WorkingDir (nếu có + tồn tại) → file-write của agent rơi vào đúng project (sandbox).
    # Push/Pop-Location cô lập cwd quanh đúng lời gọi; finally đảm bảo restore dù throw.
    $pushed = $false
    if (-not [string]::IsNullOrWhiteSpace($WorkingDir) -and (Test-Path -LiteralPath $WorkingDir)) {
        Push-Location -LiteralPath $WorkingDir
        $pushed = $true
    }
    try {
        # 2>$errFile (KHÔNG 2>&1): stderr → file; $raw chỉ nhận stdout (JSON sạch).
        $raw = $Prompt | & claude @claudeArgs 2>$errFile
    }
    finally {
        if ($pushed) { Pop-Location }
    }

    # Surface stderr mà KHÔNG mất nó: nếu có RunDir → đã persist trong claude.stderr.log + log WARN;
    # nếu không → Write-Warning rồi xoá file tạm.
    $errText = if (Test-Path -LiteralPath $errFile) { (Get-Content -Raw -LiteralPath $errFile -ErrorAction SilentlyContinue) } else { '' }
    if ($errText -and $errText.Trim()) {
        if ($persistErr -and (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
            Write-Log "claude stderr (node='$NodeId' agent='$agent') → $errFile" -Level WARN
        } else {
            Write-Warning "claude CLI stderr [$agent]: $($errText.Trim())"
        }
    }
    if (-not $persistErr -and (Test-Path -LiteralPath $errFile)) {
        Remove-Item -LiteralPath $errFile -ErrorAction SilentlyContinue
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Invoke-Claude: claude CLI exit $LASTEXITCODE — $($errText.Trim())"
    }

    # claude --output-format json trả object có field .result chứa text.
    try {
        $parsed = ($raw | Out-String) | ConvertFrom-Json
        if ($parsed.PSObject.Properties.Name -contains 'result') {
            return [string]$parsed.result
        }
        return ($raw | Out-String).TrimEnd()
    }
    catch {
        return ($raw | Out-String).TrimEnd()
    }
}
