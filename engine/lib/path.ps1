# lib/path.ps1 — guard ngăn-chặn path (dot-source để dùng).
# Implement Session C.4 (A-14 + A-25).
#
# Vì sao cần: nhiều call-site guard "path X có nằm TRONG thư mục root không?" bằng
# `$x.StartsWith($root)` — THIẾU separator → path anh-em cùng tiền-tố lọt qua
# (vd root=".../projects", candidate=".../projects-evil" → StartsWith TRUE sai).
# Gom 1 nguồn quy tắc tại đây cho mọi call-site (sandbox.ps1 Remove-Sandbox + e2e.ps1 Promote-Branch).

Set-StrictMode -Version Latest

function Test-PathInside {
    <#
    .SYNOPSIS
        True nếu $Candidate nằm TRONG $Root (là chính $Root hoặc con thật của nó).
        Chặn bug path anh-em cùng tiền-tố: so theo ranh-giới separator, KHÔNG chỉ StartsWith thô.
    .DESCRIPTION
        Cả 2 tham số nên là đường dẫn TUYỆT ĐỐI đã resolve (caller gọi Resolve-Path trước).
        Quy tắc: chuẩn-hoá bỏ separator cuối → bằng nhau (root) HOẶC bắt đầu bằng `root + sep` (con).
        ".../projects-evil" KHÔNG nằm trong ".../projects" (khác segment) → trả $false.
    .PARAMETER Root      Thư mục root tuyệt đối.
    .PARAMETER Candidate Đường dẫn tuyệt đối cần kiểm.
    .OUTPUTS [bool]
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$Root,
        [Parameter(Mandatory, Position = 1)][string]$Candidate
    )
    $sep = [IO.Path]::DirectorySeparatorChar
    $r = $Root.TrimEnd($sep)
    $c = $Candidate.TrimEnd($sep)
    if ($c -eq $r) { return $true }
    return $c.StartsWith($r + $sep)
}
