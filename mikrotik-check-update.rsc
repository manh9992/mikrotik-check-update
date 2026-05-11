# ============================================================
# MikroTik RouterOS 7 - Auto Check Update & Telegram Notify
# ============================================================
# Script chạy trực tiếp trên router MikroTik
# Kiểm tra phiên bản mới và gửi thông báo qua Telegram
#
# CÁCH CÀI ĐẶT:
#   Bước 1: Paste toàn bộ nội dung file này vào Terminal router
#   Bước 2: Sửa 2 biến botToken và chatId bên dưới
#   Bước 3: Script sẽ tự tạo scheduler chạy lúc 5h sáng mỗi ngày
#
# HOẶC import qua file:
#   Upload file .rsc lên router → /import file-name=mikrotik-check-update.rsc
# ============================================================


# ============================================================
# BƯỚC 1: TẠO SCRIPT KIỂM TRA UPDATE
# ============================================================

/system script remove [find name="check-routeros-update"] 

/system script add name="check-routeros-update" policy=read,write,policy,test source={

    # ==================================
    # CẤU HÌNH TELEGRAM - SỬA Ở ĐÂY
    # ==================================
    :local botToken ""
    :local chatId ""

    # ==================================
    # LOGIC KIỂM TRA
    # ==================================

    :local scriptName "check-routeros-update"
    :local currentVersion [/system resource get version]
    :local currentChannel [/system package update get channel]

    :log info "$scriptName: Bat dau kiem tra cap nhat RouterOS..."
    :log info "$scriptName: Phien ban hien tai: $currentVersion (channel: $currentChannel)"

    # Kiểm tra update từ server MikroTik
    :do {
        /system package update check-for-updates
    } on-error={
        :log error "$scriptName: Khong the ket noi den server MikroTik!"
        :error "Khong the kiem tra update"
    }

    # Đợi vài giây để server phản hồi
    :delay 5s

    # Lấy thông tin version mới nhất
    :local latestVersion [/system package update get latest-version]
    :local installedVersion [/system package update get installed-version]
    :local updateStatus [/system package update get status]

    :log info "$scriptName: Installed: $installedVersion"
    :log info "$scriptName: Latest: $latestVersion"
    :log info "$scriptName: Status: $updateStatus"

    # Lấy thông tin router
    :local identity [/system identity get name]
    :local boardName [/system resource get board-name]
    :local architecture [/system resource get architecture-name]
    :local uptime [/system resource get uptime]
    :local cpuLoad [/system resource get cpu-load]
    :local freeMemPercent
    :local totalMem [/system resource get total-memory]
    :local freeMem [/system resource get free-memory]
    :set freeMemPercent (($freeMem * 100) / $totalMem)

    # So sánh version
    :if ($latestVersion != $installedVersion) do={

        :log warning "$scriptName: CO PHIEN BAN MOI! $installedVersion -> $latestVersion"

        # ==================================
        # AUTO BACKUP TRƯỚC KHI THÔNG BÁO
        # ==================================
        :local dateStr [/system clock get date]
        :local backupName "backup-v$installedVersion-$dateStr"
        :local backupStatus "OK"

        :log info "$scriptName: Dang tao backup truoc khi update..."

        # Binary backup (.backup)
        :do {
            /system backup save name=$backupName dont-encrypt=yes
            :log info "$scriptName: Binary backup thanh cong: $backupName.backup"
        } on-error={
            :log error "$scriptName: LOI tao binary backup!"
            :set backupStatus "LOI binary backup"
        }

        :delay 3s

        # Text export (.rsc)
        :do {
            /export file=$backupName
            :log info "$scriptName: Export thanh cong: $backupName.rsc"
        } on-error={
            :log error "$scriptName: LOI tao export!"
            :set backupStatus ($backupStatus . " + LOI export")
        }

        :delay 2s

        # Tạo message Telegram (URL encoded)
        :local message ("\F0\9F\94\94 <b>RouterOS - Phien Ban Moi\21</b>%0A" . \
            "%0A" . \
            "\F0\9F\96\A5 <b>Router:</b> <code>$identity</code>%0A" . \
            "\F0\9F\93\8B <b>Model:</b> <code>$boardName ($architecture)</code>%0A" . \
            "\E2\8F\B0 <b>Uptime:</b> <code>$uptime</code>%0A" . \
            "%0A" . \
            "\F0\9F\93\A6 <b>Phien ban hien tai:</b> <code>$installedVersion</code>%0A" . \
            "\F0\9F\86\95 <b>Phien ban moi:</b> <code>$latestVersion</code>%0A" . \
            "\F0\9F\94\80 <b>Channel:</b> <code>$currentChannel</code>%0A" . \
            "%0A" . \
            "\F0\9F\93\8A <b>Tinh trang router:</b>%0A" . \
            "   \E2\80\A2 CPU: <code>$cpuLoad%25</code>%0A" . \
            "   \E2\80\A2 Free RAM: <code>$freeMemPercent%25</code>%0A" . \
            "%0A" . \
            "\F0\9F\92\BE <b>Auto Backup:</b>%0A" . \
            "   \E2\80\A2 File: <code>$backupName.backup</code>%0A" . \
            "   \E2\80\A2 Export: <code>$backupName.rsc</code>%0A" . \
            "   \E2\80\A2 Trang thai: <code>$backupStatus</code>%0A" . \
            "%0A" . \
            "\F0\9F\94\97 <a href='https://mikrotik.com/download/changelogs'>Xem Changelog</a> | " . \
            "<a href='https://mikrotik.com/download'>Download</a>%0A" . \
            "%0A" . \
            "\E2\9C\85 <i>Da tu dong backup xong, san sang update\21</i>")

        # Gửi qua Telegram
        :local telegramUrl "https://api.telegram.org/bot$botToken/sendMessage\?chat_id=$chatId&parse_mode=HTML&text=$message"

        :do {
            /tool fetch url=$telegramUrl mode=https keep-result=no
            :log info "$scriptName: Da gui thong bao Telegram thanh cong!"
        } on-error={
            :log error "$scriptName: LOI gui Telegram! Kiem tra bot token va chat id."
        }

    } else={

        :log info "$scriptName: Khong co ban cap nhat moi. Phien ban hien tai ($installedVersion) la moi nhat."

    }

    :log info "$scriptName: Hoan tat kiem tra."
}


# ============================================================
# BƯỚC 2: TẠO SCRIPT TEST (giả lập có bản cập nhật mới)
# ============================================================

/system script remove [find name="test-check-update"]

/system script add name="test-check-update" policy=read,write,policy,test source={

    # ==================================
    # CẤU HÌNH TELEGRAM - GIỐNG SCRIPT CHÍNH
    # ==================================
    :local botToken "7683647561:AAE-R2HR2szGQJiR1N0oeHlY7uAeRolXxuU"
    :local chatId "-1002306257786"

    # Lấy thông tin router thật
    :local identity [/system identity get name]
    :local boardName [/system resource get board-name]
    :local architecture [/system resource get architecture-name]
    :local uptime [/system resource get uptime]
    :local cpuLoad [/system resource get cpu-load]
    :local totalMem [/system resource get total-memory]
    :local freeMem [/system resource get free-memory]
    :local freeMemPercent (($freeMem * 100) / $totalMem)
    :local installedVersion [/system resource get version]
    :local currentChannel [/system package update get channel]

    # Fake version mới
    :local fakeNewVersion "7.99.0"

    :log info "test-check-update: GUI TEST thong bao Telegram..."

    # ==================================
    # AUTO BACKUP (THẬT) - TEST LUÔN
    # ==================================
    :local dateStr [/system clock get date]
    :local backupName "test-backup-v$installedVersion-$dateStr"
    :local backupStatus "OK"

    :log info "test-check-update: Dang tao backup..."

    # Binary backup (.backup)
    :do {
        /system backup save name=$backupName dont-encrypt=yes
        :log info "test-check-update: Binary backup OK: $backupName.backup"
        :put "Binary backup OK: $backupName.backup"
    } on-error={
        :log error "test-check-update: LOI binary backup!"
        :set backupStatus "LOI binary backup"
        :put "LOI binary backup!"
    }

    :delay 3s

    # Text export (.rsc)
    :do {
        /export file=$backupName
        :log info "test-check-update: Export OK: $backupName.rsc"
        :put "Export OK: $backupName.rsc"
    } on-error={
        :log error "test-check-update: LOI export!"
        :set backupStatus ($backupStatus . " + LOI export")
        :put "LOI export!"
    }

    :delay 2s

    # Tạo message Telegram
    :local message ("\F0\9F\94\94 <b>RouterOS - Phien Ban Moi\21</b>%0A" . \
        "%0A" . \
        "\F0\9F\96\A5 <b>Router:</b> <code>$identity</code>%0A" . \
        "\F0\9F\93\8B <b>Model:</b> <code>$boardName ($architecture)</code>%0A" . \
        "\E2\8F\B0 <b>Uptime:</b> <code>$uptime</code>%0A" . \
        "%0A" . \
        "\F0\9F\93\A6 <b>Phien ban hien tai:</b> <code>$installedVersion</code>%0A" . \
        "\F0\9F\86\95 <b>Phien ban moi:</b> <code>$fakeNewVersion</code>%0A" . \
        "\F0\9F\94\80 <b>Channel:</b> <code>$currentChannel</code>%0A" . \
        "%0A" . \
        "\F0\9F\93\8A <b>Tinh trang router:</b>%0A" . \
        "   \E2\80\A2 CPU: <code>$cpuLoad%25</code>%0A" . \
        "   \E2\80\A2 Free RAM: <code>$freeMemPercent%25</code>%0A" . \
        "%0A" . \
        "\F0\9F\92\BE <b>Auto Backup:</b>%0A" . \
        "   \E2\80\A2 File: <code>$backupName.backup</code>%0A" . \
        "   \E2\80\A2 Export: <code>$backupName.rsc</code>%0A" . \
        "   \E2\80\A2 Trang thai: <code>$backupStatus</code>%0A" . \
        "%0A" . \
        "\F0\9F\94\97 <a href='https://mikrotik.com/download/changelogs'>Xem Changelog</a> | " . \
        "<a href='https://mikrotik.com/download'>Download</a>%0A" . \
        "%0A" . \
        "\E2\9C\85 <i>Da tu dong backup xong, san sang update\21</i>%0A" . \
        "%0A" . \
        "\E2\9A\A0\EF\B8\8F <b>DAY LA TIN NHAN TEST - KHONG PHAI UPDATE THAT\21</b>")

    :local telegramUrl "https://api.telegram.org/bot$botToken/sendMessage\?chat_id=$chatId&parse_mode=HTML&text=$message"

    :do {
        /tool fetch url=$telegramUrl mode=https keep-result=no
        :log info "test-check-update: Da gui test Telegram thanh cong!"
        :put "OK! Da gui test Telegram. Kiem tra tin nhan tren Telegram."
    } on-error={
        :log error "test-check-update: LOI gui Telegram!"
        :put "LOI! Khong gui duoc. Kiem tra bot token va chat id."
    }

    :put ""
    :put "Xong! Kiem tra Files tren router de thay file backup."
    :put "Xoa file test backup: /file remove [find name~\"test-backup\"]"
}


# ============================================================
# BƯỚC 3: TẠO SCHEDULER CHẠY LÚC 5H SÁNG MỖI NGÀY
# ============================================================

/system scheduler remove [find name="schedule-check-update"]

/system scheduler add \
    name="schedule-check-update" \
    start-date=[/system clock get date] \
    start-time=05:00:00 \
    interval=1d \
    on-event="/system script run check-routeros-update" \
    policy=read,write,policy,test \
    comment="Kiem tra cap nhat RouterOS moi ngay luc 5h sang - gui Telegram"


# ============================================================
# THÔNG BÁO HOÀN TẤT
# ============================================================

:log info "=========================================="
:log info "DA CAI DAT THANH CONG!"
:log info "Script: check-routeros-update + test-check-update"
:log info "Scheduler: Moi ngay luc 05:00"
:log info "=========================================="
:put "============================================"
:put "DA CAI DAT THANH CONG!"
:put ""
:put "Script chinh : check-routeros-update"
:put "Script test  : test-check-update"
:put "Scheduler    : schedule-check-update (05:00 moi ngay)"
:put ""
:put "TEST GUI TELEGRAM:"
:put "  /system script run test-check-update"
:put ""
:put "CHAY THAT:"
:put "  /system script run check-routeros-update"
:put "============================================"
