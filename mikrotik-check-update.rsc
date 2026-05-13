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
# CẤU HÌNH - SỬA TOKEN VÀ CHAT ID Ở ĐÂY TRƯỚC KHI IMPORT
# ============================================================

:global telegramBotToken "YOUR_BOT_TOKEN_HERE"
:global telegramChatId "YOUR_CHAT_ID_HERE"


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

    :log info ("$scriptName: B\E1\BA\AFt \C4\91\E1\BA\A7u ki\E1\BB\83m tra c\E1\BA\ADp nh\E1\BA\ADt RouterOS...")
    :log info ("$scriptName: Phi\C3\AAn b\E1\BA\A3n hi\E1\BB\87n t\E1\BA\A1i: " . $currentVersion)

    # Kiểm tra update từ server MikroTik
    :do {
        /system package update check-for-updates
    } on-error={
        :log error "$scriptName: Kh\C3\B4ng th\E1\BB\83 k\E1\BA\BFt n\E1\BB\91i \C4\91\E1\BA\BFn server MikroTik!"
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

        :log warning ("$scriptName: C\C3\93 PHI\C3\8AN B\E1\BA\A2N M\E1\BB\9AI! " . $installedVersion . " -> " . $latestVersion)

        # Tự động sao lưu
        :local dateStr [/system clock get date]
        :local backupName ("backup-v" . $installedVersion . "-" . $dateStr)
        :local backupStatus "OK"

        :do {
            /system backup save name=$backupName dont-encrypt=yes
            :log info ("$scriptName: Binary backup OK: " . $backupName . ".backup")
        } on-error={
            :log error "$scriptName: L\E1\BB\96I backup!"
            :set backupStatus "L\E1\BB\96I binary backup"
        }

        :delay 3s

        :do {
            /export file=$backupName
            :log info ("$scriptName: Export OK: " . $backupName . ".rsc")
        } on-error={
            :log error "$scriptName: L\E1\BB\96I export!"
            :set backupStatus ($backupStatus . " + L\E1\BB\96I export")
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
            :log info "$scriptName: \C4\90\C3\A3 g\E1\BB\ADi Telegram th\C3\A0nh c\C3\B4ng!"
            /system script set [find name=$scriptName] comment=$latestVersion
        } on-error={
            :log error "$scriptName: L\E1\BB\96I g\E1\BB\ADi Telegram!"
        }

    } else={

        :if ($latestVersion = $installedVersion) do={
            :log info ("$scriptName: Kh\C3\B4ng c\C3\B3 b\E1\BA\A3n c\E1\BA\ADp nh\E1\BA\ADt m\E1\BB\9Bi. (" . $installedVersion . ")")
        } else={
            :log info ("$scriptName: Version " . $latestVersion . " \C4\91\C3\A3 th\C3\B4ng b\C3\A1o r\E1\BB\93i. B\E1\BB\8F qua.")
        }

    }

    :log info "$scriptName: Ho\C3\A0n t\E1\BA\A5t ki\E1\BB\83m tra."
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
    :put "TEST: Ki\E1\BB\83m tra ch\E1\BB\91ng tr\C3\B9ng th\C3\B4ng b\C3\A1o"
    :put "============================================"
    :put ("Phi\C3\AAn b\E1\BA\A3n hi\E1\BB\87n t\E1\BA\A1i : " . $installedVersion)
    :put ("Phi\C3\AAn b\E1\BA\A3n m\E1\BB\9Bi (fake): " . $fakeNewVersion)
    :put ("\C4\90\C3\A3 th\C3\B4ng b\C3\A1o       : " . $lastNotified)
    :put ("Bot token length  : " . [:len $telegramBotToken])
    :put ("Chat ID           : " . $telegramChatId)
    :put ""

    :if ($fakeNewVersion != $installedVersion && $fakeNewVersion != $lastNotified) do={

        :put ">> C\C3\93 b\E1\BA\A3n m\E1\BB\9Bi ch\C6\B0a th\C3\B4ng b\C3\A1o! Ti\E1\BA\BFn h\C3\A0nh sao l\C6\B0u + g\E1\BB\ADi Telegram..."

        :local dateStr [/system clock get date]
        :local backupName ("test-backup-v" . $installedVersion . "-" . $dateStr)
        :local backupStatus "OK"

        :do {
            /system backup save name=$backupName dont-encrypt=yes
            :put ("Binary backup OK: " . $backupName . ".backup")
        } on-error={
            :set backupStatus "L\E1\BB\96I binary backup"
            :put "L\E1\BB\96I binary backup!"
        }

        :delay 3s

        :do {
            /export file=$backupName
            :put ("Export OK: " . $backupName . ".rsc")
        } on-error={
            :set backupStatus ($backupStatus . " + L\E1\BB\96I export")
            :put "L\E1\BB\96I export!"
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
            :put "OK! \C4\90\C3\A3 g\E1\BB\ADi Telegram th\C3\A0nh c\C3\B4ng."
            /system script set [find name=$scriptName] comment=$fakeNewVersion
            :put ("\C4\90\C3\A3 l\C6\B0u notified version: " . $fakeNewVersion)
        } on-error={
            :put "L\E1\BB\96I! Kh\C3\B4ng g\E1\BB\ADi \C4\91\C6\B0\E1\BB\A3c. Ki\E1\BB\83m tra bot token v\C3\A0 chat id."
        }

        :put ""
        :put "Ki\E1\BB\83m tra Files tr\C3\AAn router \C4\91\E1\BB\83 th\E1\BA\A5y file backup."
        :put "X\C3\B3a file test: /file remove [find name~\"test-backup\"]"

    } else={

        :put ("\C4\90\C3\A3 th\C3\B4ng b\C3\A1o version " . $fakeNewVersion . " tr\C6\B0\E1\BB\9Bc \C4\91\C3\B3 r\E1\BB\93i. B\E1\BB\8F qua.")
        :put ""
        :put "Test l\E1\BA\A1i t\E1\BB\AB \C4\91\E1\BA\A7u:"
        :put "  /system script set test-check-update comment=\"\""

    }

    :put "============================================"
}


# ============================================================
# SCHEDULER: TỰ ĐỘNG CHẠY LÚC 5H SÁNG MỖI NGÀY
# ============================================================

/system scheduler remove [find name="schedule-check-update"]

/system scheduler add \
    name="schedule-check-update" \
    start-date=[/system clock get date] \
    start-time=05:00:00 \
    interval=1d \
    on-event=":global telegramBotToken \"YOUR_BOT_TOKEN_HERE\"\r\n:global telegramChatId \"YOUR_CHAT_ID_HERE\"\r\n/system script run check-routeros-update" \
    policy=read,write,policy,test \
    comment="Auto check RouterOS update - daily 5AM"


# ============================================================
# HOÀN TẤT CÀI ĐẶT
# ============================================================

:put ""
:put "============================================"
:put " \E2\9C\85 C\C3\80I \C4\90\E1\BA\B6T TH\C3\80NH C\C3\94NG!"
:put "============================================"
:put ""
:put " Script ch\C3\ADnh : check-routeros-update"
:put " Script test  : test-check-update"
:put " Scheduler    : schedule-check-update (05:00)"
:put ""
:put " Test ngay:"
:put "   /system script run test-check-update"
:put ""
:put " Ch\E1\BA\A1y th\E1\BA\ADt:"
:put "   /system script run check-routeros-update"
:put ""
:put "============================================"
