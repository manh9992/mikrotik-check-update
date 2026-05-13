# ============================================================
# MikroTik RouterOS 7 - Auto Check Update & Telegram Notify
# ============================================================
# Script chạy trực tiếp trên router MikroTik RouterOS 7
# Tự động kiểm tra phiên bản mới, sao lưu cấu hình và
# gửi thông báo qua Telegram.
#
# Tính năng:
#   - Kiểm tra cập nhật từ server MikroTik chính thức
#   - Tự động sao lưu (binary .backup + text .rsc) khi có bản mới
#   - Gửi thông báo Telegram với thông tin chi tiết
#   - Chống gửi trùng lặp (lưu version đã thông báo)
#   - Scheduler tự động chạy lúc 5h sáng mỗi ngày
#
# Cài đặt:
#   1. Sửa telegramBotToken và telegramChatId bên dưới
#   2. Upload file lên router (Winbox > Files)
#   3. Chạy: /import file-name=mikrotik-check-update.rsc
#   4. Test:  /system script run test-check-update
# ============================================================


# ============================================================
# CẤU HÌNH - SỬA TOKEN VÀ CHAT ID TRONG SCRIPT set-telegram-config
# (Ở gần cuối file, tìm "SCRIPT 3")
# ============================================================


# ============================================================
# SCRIPT 1: KIỂM TRA CẬP NHẬT (script chính)
# ============================================================

/system script remove [find name="check-routeros-update"]

/system script add name="check-routeros-update" policy=read,write,policy,test comment="" source={

    :global telegramBotToken
    :global telegramChatId

    :local scriptName "check-routeros-update"
    :local currentVersion [/system resource get version]
    :local currentChannel [/system package update get channel]

    :log info ("$scriptName: Bat dau kiem tra cap nhat RouterOS...")
    :log info ("$scriptName: Phien ban hien tai: " . $currentVersion)

    # Kiểm tra update từ server MikroTik
    :do {
        /system package update check-for-updates
    } on-error={
        :log error "$scriptName: Khong the ket noi den server MikroTik!"
        :error "Connection failed"
    }

    :delay 5s

    :local latestVersion [/system package update get latest-version]
    :local installedVersion [/system package update get installed-version]
    :local updateStatus [/system package update get status]

    :log info ("$scriptName: Installed: " . $installedVersion)
    :log info ("$scriptName: Latest: " . $latestVersion)

    # Đọc version đã thông báo lần trước
    :local lastNotified [/system script get [find name=$scriptName] comment]

    # Lấy thông tin router
    :local identity [/system identity get name]
    :local boardName [/system resource get board-name]
    :local architecture [/system resource get architecture-name]
    :local uptime [/system resource get uptime]
    :local cpuLoad [/system resource get cpu-load]
    :local totalMem [/system resource get total-memory]
    :local freeMem [/system resource get free-memory]
    :local freeMemPercent (($freeMem * 100) / $totalMem)

    # So sánh: có bản mới VÀ chưa thông báo version này
    :if ($latestVersion != $installedVersion && $latestVersion != $lastNotified) do={

        :log warning ("$scriptName: CO PHIEN BAN MOI! " . $installedVersion . " -> " . $latestVersion)

        # Tự động sao lưu
        :local dateStr [/system clock get date]
        :local backupName ("backup-v" . $installedVersion . "-" . $dateStr)
        :local backupStatus "OK"

        :do {
            /system backup save name=$backupName dont-encrypt=yes
            :log info ("$scriptName: Binary backup OK: " . $backupName . ".backup")
        } on-error={
            :log error "$scriptName: LOI backup!"
            :set backupStatus "LOI binary backup"
        }

        :delay 3s

        :do {
            /export file=$backupName
            :log info ("$scriptName: Export OK: " . $backupName . ".rsc")
        } on-error={
            :log error "$scriptName: LOI export!"
            :set backupStatus ($backupStatus . " + LOI export")
        }

        :delay 2s

        # Tạo tin nhắn Telegram
        :local msg ""
        :set msg ($msg . "\F0\9F\94\94 <b>RouterOS - Phi\C3\AAn B\E1\BA\A3n M\E1\BB\9Bi!</b>\n")
        :set msg ($msg . "\n")
        :set msg ($msg . "\F0\9F\96\A5 <b>Router:</b> <code>" . $identity . "</code>\n")
        :set msg ($msg . "\F0\9F\93\8B <b>Model:</b> <code>" . $boardName . " (" . $architecture . ")</code>\n")
        :set msg ($msg . "\E2\8F\B0 <b>Uptime:</b> <code>" . $uptime . "</code>\n")
        :set msg ($msg . "\n")
        :set msg ($msg . "\F0\9F\93\A6 <b>Phi\C3\AAn b\E1\BA\A3n hi\E1\BB\87n t\E1\BA\A1i:</b> <code>" . $installedVersion . "</code>\n")
        :set msg ($msg . "\F0\9F\86\95 <b>Phi\C3\AAn b\E1\BA\A3n m\E1\BB\9Bi:</b> <code>" . $latestVersion . "</code>\n")
        :set msg ($msg . "\F0\9F\94\80 <b>K\C3\AAnh c\E1\BA\ADp nh\E1\BA\ADt:</b> <code>" . $currentChannel . "</code>\n")
        :set msg ($msg . "\n")
        :set msg ($msg . "\F0\9F\93\8A <b>T\C3\ACnh tr\E1\BA\A1ng router:</b>\n")
        :set msg ($msg . "   \E2\80\A2 CPU: <code>" . $cpuLoad . "%</code>\n")
        :set msg ($msg . "   \E2\80\A2 RAM tr\E1\BB\91ng: <code>" . $freeMemPercent . "%</code>\n")
        :set msg ($msg . "\n")
        :set msg ($msg . "\F0\9F\92\BE <b>Sao l\C6\B0u t\E1\BB\B1 \C4\91\E1\BB\99ng:</b>\n")
        :set msg ($msg . "   \E2\80\A2 File: <code>" . $backupName . ".backup</code>\n")
        :set msg ($msg . "   \E2\80\A2 Export: <code>" . $backupName . ".rsc</code>\n")
        :set msg ($msg . "   \E2\80\A2 Tr\E1\BA\A1ng th\C3\A1i: <code>" . $backupStatus . "</code>\n")
        :set msg ($msg . "\n")
        :set msg ($msg . "\F0\9F\94\97 <a href='https://mikrotik.com/download/changelogs'>Xem Changelog</a> | ")
        :set msg ($msg . "<a href='https://mikrotik.com/download'>T\E1\BA\A3i v\E1\BB\81</a>\n")
        :set msg ($msg . "\n")
        :set msg ($msg . "\E2\9C\85 <i>\C4\90\C3\A3 t\E1\BB\B1 \C4\91\E1\BB\99ng sao l\C6\B0u xong, s\E1\BA\B5n s\C3\A0ng c\E1\BA\ADp nh\E1\BA\ADt!</i>")

        # Gửi Telegram
        :local apiUrl ("https://api.telegram.org/bot" . $telegramBotToken . "/sendMessage")
        :local postData ("chat_id=" . $telegramChatId . "&parse_mode=HTML&text=" . $msg)

        :do {
            /tool fetch url=$apiUrl http-method=post http-data=$postData output=none
            :log info "$scriptName: Da gui Telegram thanh cong!"
            /system script set [find name=$scriptName] comment=$latestVersion
        } on-error={
            :log error "$scriptName: LOI gui Telegram!"
        }

    } else={

        :if ($latestVersion = $installedVersion) do={
            :log info ("$scriptName: Khong co ban cap nhat moi. (" . $installedVersion . ")")
        } else={
            :log info ("$scriptName: Version " . $latestVersion . " da thong bao roi. Bo qua.")
        }

    }

    :log info "$scriptName: Hoan tat kiem tra."
}


# ============================================================
# SCRIPT 2: TEST GỬI TELEGRAM (giả lập có bản cập nhật mới)
# ============================================================

/system script remove [find name="test-check-update"]

/system script add name="test-check-update" policy=read,write,policy,test comment="" source={

    :global telegramBotToken
    :global telegramChatId

    :local scriptName "test-check-update"

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
    :local fakeNewVersion "7.99.0"
    :local lastNotified [/system script get [find name=$scriptName] comment]

    :put "============================================"
    :put "TEST: Kiem tra chong trung thong bao"
    :put "============================================"
    :put ("Phien ban hien tai : " . $installedVersion)
    :put ("Phien ban moi (fake): " . $fakeNewVersion)
    :put ("Da thong bao        : " . $lastNotified)
    :put ("Bot token length    : " . [:len $telegramBotToken])
    :put ("Chat ID             : " . $telegramChatId)
    :put ""

    :if ($fakeNewVersion != $installedVersion && $fakeNewVersion != $lastNotified) do={

        :put ">> CO ban moi chua thong bao! Tien hanh sao luu + gui Telegram..."

        :local dateStr [/system clock get date]
        :local backupName ("test-backup-v" . $installedVersion . "-" . $dateStr)
        :local backupStatus "OK"

        :do {
            /system backup save name=$backupName dont-encrypt=yes
            :put ("Binary backup OK: " . $backupName . ".backup")
        } on-error={
            :set backupStatus "LOI binary backup"
            :put "LOI binary backup!"
        }

        :delay 3s

        :do {
            /export file=$backupName
            :put ("Export OK: " . $backupName . ".rsc")
        } on-error={
            :set backupStatus ($backupStatus . " + LOI export")
            :put "LOI export!"
        }

        :delay 2s

        :local msg ""
        :set msg ($msg . "\F0\9F\94\94 <b>RouterOS - Phi\C3\AAn B\E1\BA\A3n M\E1\BB\9Bi!</b>\n")
        :set msg ($msg . "\n")
        :set msg ($msg . "\F0\9F\96\A5 <b>Router:</b> <code>" . $identity . "</code>\n")
        :set msg ($msg . "\F0\9F\93\8B <b>Model:</b> <code>" . $boardName . " (" . $architecture . ")</code>\n")
        :set msg ($msg . "\E2\8F\B0 <b>Uptime:</b> <code>" . $uptime . "</code>\n")
        :set msg ($msg . "\n")
        :set msg ($msg . "\F0\9F\93\A6 <b>Phi\C3\AAn b\E1\BA\A3n hi\E1\BB\87n t\E1\BA\A1i:</b> <code>" . $installedVersion . "</code>\n")
        :set msg ($msg . "\F0\9F\86\95 <b>Phi\C3\AAn b\E1\BA\A3n m\E1\BB\9Bi:</b> <code>" . $fakeNewVersion . "</code>\n")
        :set msg ($msg . "\F0\9F\94\80 <b>K\C3\AAnh c\E1\BA\ADp nh\E1\BA\ADt:</b> <code>" . $currentChannel . "</code>\n")
        :set msg ($msg . "\n")
        :set msg ($msg . "\F0\9F\93\8A <b>T\C3\ACnh tr\E1\BA\A1ng router:</b>\n")
        :set msg ($msg . "   \E2\80\A2 CPU: <code>" . $cpuLoad . "%</code>\n")
        :set msg ($msg . "   \E2\80\A2 RAM tr\E1\BB\91ng: <code>" . $freeMemPercent . "%</code>\n")
        :set msg ($msg . "\n")
        :set msg ($msg . "\F0\9F\92\BE <b>Sao l\C6\B0u t\E1\BB\B1 \C4\91\E1\BB\99ng:</b>\n")
        :set msg ($msg . "   \E2\80\A2 File: <code>" . $backupName . ".backup</code>\n")
        :set msg ($msg . "   \E2\80\A2 Export: <code>" . $backupName . ".rsc</code>\n")
        :set msg ($msg . "   \E2\80\A2 Tr\E1\BA\A1ng th\C3\A1i: <code>" . $backupStatus . "</code>\n")
        :set msg ($msg . "\n")
        :set msg ($msg . "\F0\9F\94\97 <a href='https://mikrotik.com/download/changelogs'>Xem Changelog</a> | ")
        :set msg ($msg . "<a href='https://mikrotik.com/download'>T\E1\BA\A3i v\E1\BB\81</a>\n")
        :set msg ($msg . "\n")
        :set msg ($msg . "\E2\9C\85 <i>\C4\90\C3\A3 t\E1\BB\B1 \C4\91\E1\BB\99ng sao l\C6\B0u xong, s\E1\BA\B5n s\C3\A0ng c\E1\BA\ADp nh\E1\BA\ADt!</i>\n")
        :set msg ($msg . "\n")
        :set msg ($msg . "\E2\9A\A0\EF\B8\8F <b>\C4\90\C3\82Y L\C3\80 TIN NH\E1\BA\AEN TEST - KH\C3\94NG PH\E1\BA\A2I C\E1\BA\ACP NH\E1\BA\ACT TH\E1\BA\ACT!</b>")

        :local apiUrl ("https://api.telegram.org/bot" . $telegramBotToken . "/sendMessage")
        :local postData ("chat_id=" . $telegramChatId . "&parse_mode=HTML&text=" . $msg)

        :do {
            /tool fetch url=$apiUrl http-method=post http-data=$postData output=none
            :put ""
            :put "OK! Da gui Telegram thanh cong."
            /system script set [find name=$scriptName] comment=$fakeNewVersion
            :put ("Da luu notified version: " . $fakeNewVersion)
        } on-error={
            :put "LOI! Khong gui duoc. Kiem tra bot token va chat id."
        }

        :put ""
        :put "Kiem tra Files tren router de thay file backup."
        :put "Xoa file test: /file remove [find name~\"test-backup\"]"

    } else={

        :put ("Da thong bao version " . $fakeNewVersion . " truoc do roi. Bo qua.")
        :put ""
        :put "Test lai tu dau:"
        :put "  /system script set test-check-update comment=\"\""

    }

    :put "============================================"
}


# ============================================================
# SCRIPT 3: SET CẤU HÌNH TELEGRAM (chạy khi startup/reboot)
# ============================================================

/system script remove [find name="set-telegram-config"]

/system script add name="set-telegram-config" policy=read,write,policy,test source={
    :global telegramBotToken "YOUR_BOT_TOKEN_HERE"
    :global telegramChatId "YOUR_CHAT_ID_HERE"
    :log info "set-telegram-config: Da set Telegram global variables."
}

# Set luôn lần đầu
/system script run set-telegram-config


# ============================================================
# SCHEDULER 1: KHỞI ĐỘNG - Set lại global variables sau reboot
# ============================================================

/system scheduler remove [find name="startup-telegram-config"]

/system scheduler add \
    name="startup-telegram-config" \
    on-event="/system script run set-telegram-config" \
    start-time=startup \
    policy=read,write,policy,test \
    comment="Set Telegram token sau moi lan reboot"


# ============================================================
# SCHEDULER 2: TỰ ĐỘNG KIỂM TRA LÚC 5H SÁNG MỖI NGÀY
# ============================================================

/system scheduler remove [find name="schedule-check-update"]

/system scheduler add \
    name="schedule-check-update" \
    start-date=[/system clock get date] \
    start-time=05:00:00 \
    interval=1d \
    on-event="/system script run check-routeros-update" \
    policy=read,write,policy,test \
    comment="Auto check RouterOS update - daily 5AM"


# ============================================================
# HOÀN TẤT CÀI ĐẶT
# ============================================================

:put ""
:put "============================================"
:put " CAI DAT THANH CONG!"
:put "============================================"
:put ""
:put " Script chinh  : check-routeros-update"
:put " Script test   : test-check-update"
:put " Script config : set-telegram-config"
:put " Scheduler     : startup-telegram-config (startup)"
:put "                 schedule-check-update (05:00)"
:put ""
:put " Test ngay:"
:put "   /system script run test-check-update"
:put ""
:put " Chay that:"
:put "   /system script run check-routeros-update"
:put ""
:put "============================================"
