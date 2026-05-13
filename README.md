# 🔍 MikroTik RouterOS 7 - Auto Check Update & Telegram Notify

Script chạy trực tiếp trên **router MikroTik RouterOS 7**, tự động kiểm tra phiên bản mới, **sao lưu cấu hình** và gửi thông báo qua **Telegram**.

## ✨ Tính năng

- ✅ Chạy **native trên RouterOS** — không cần server bên ngoài
- ✅ Kiểm tra cập nhật qua `/system package update` (API chính thức)
- ✅ **Tự động sao lưu** khi có bản mới (binary `.backup` + text `.rsc`)
- ✅ Gửi thông báo Telegram **tiếng Việt có dấu** với thông tin chi tiết
- ✅ **Chống gửi trùng** — mỗi version chỉ thông báo 1 lần
- ✅ Scheduler tự động chạy lúc **5h sáng mỗi ngày**
- ✅ Script test giả lập để kiểm tra toàn bộ flow

## 📋 Flow hoạt động

```
Scheduler (5h sáng mỗi ngày)
    │
    ▼
Kiểm tra update từ MikroTik server
    │
    ├── Không có bản mới → Ghi log, kết thúc
    ├── Đã thông báo version này rồi → Bỏ qua
    │
    └── CÓ bản mới (chưa thông báo) →
            ├── 1. Sao lưu binary (.backup)
            ├── 2. Export text (.rsc)
            ├── 3. Gửi Telegram thông báo
            └── 4. Lưu version đã thông báo
```

## 🚀 Cài đặt

### Bước 1: Tạo Telegram Bot

1. Mở Telegram, chat với [@BotFather](https://t.me/BotFather)
2. Gõ `/newbot` → đặt tên → nhận **Bot Token**
3. Chat với bot vừa tạo, gõ `/start`
4. Truy cập `https://api.telegram.org/bot<TOKEN>/getUpdates` → lấy **Chat ID**

> 💡 Nếu gửi vào group: thêm bot vào group, gõ tin nhắn bất kỳ, rồi xem `getUpdates` để lấy chat ID (số âm cho group chat)

### Bước 2: Cấu hình Token & Chat ID

Mở file `mikrotik-check-update.rsc`, tìm **SCRIPT 3** (gần cuối file) và sửa **1 chỗ duy nhất**:

```routeros
/system script add name="set-telegram-config" ... source={
    :global telegramBotToken "YOUR_BOT_TOKEN_HERE"    ← Thay token thật
    :global telegramChatId "YOUR_CHAT_ID_HERE"        ← Thay chat ID thật
    ...
}
```

> 💡 Chỉ cần sửa 1 chỗ này! Token tự động được khôi phục sau mỗi lần reboot router nhờ startup scheduler.

### Bước 3: Import lên router

```bash
# Upload file qua Winbox (kéo thả vào Files), rồi:
/import file-name=mikrotik-check-update.rsc
```

### Bước 4: Test

```routeros
/system script run test-check-update
```

## 📦 Các thành phần được cài đặt

| Tên | Loại | Mô tả |
|-----|------|--------|
| `check-routeros-update` | Script | Script chính — kiểm tra, sao lưu, gửi Telegram |
| `test-check-update` | Script | Script test — giả lập có bản mới v7.99.0 |
| `set-telegram-config` | Script | Lưu token & chat ID vào global variables |
| `startup-telegram-config` | Scheduler | Khôi phục token sau mỗi lần reboot |
| `schedule-check-update` | Scheduler | Tự động chạy script chính lúc 05:00 mỗi ngày |

## 📖 Quản lý

```routeros
# Xem scripts đã cài
/system script print where name~"update"

# Xem scheduler
/system scheduler print where name="schedule-check-update"

# Chạy kiểm tra thủ công
/system script run check-routeros-update

# Tạm dừng scheduler
/system scheduler set schedule-check-update disabled=yes

# Bật lại scheduler
/system scheduler set schedule-check-update disabled=no

# Đổi giờ chạy (ví dụ 6h sáng)
/system scheduler set schedule-check-update start-time=06:00:00

# Reset chống trùng (để test lại)
/system script set test-check-update comment=""
/system script set check-routeros-update comment=""

# Gỡ cài đặt hoàn toàn
/system scheduler remove schedule-check-update
/system script remove check-routeros-update
/system script remove test-check-update
```

## 📩 Mẫu thông báo Telegram

```
🔔 RouterOS - Phiên Bản Mới!

🖥 Router: MikroTik-Home
📋 Model: RB5009UPr+S+ (arm64)
⏰ Uptime: 45d 12:30:00

📦 Phiên bản hiện tại: 7.22.3
🆕 Phiên bản mới: 7.23.0
🔀 Kênh cập nhật: stable

📊 Tình trạng router:
   • CPU: 12%
   • RAM trống: 78%

💾 Sao lưu tự động:
   • File: backup-v7.22.3-2026-05-11.backup
   • Export: backup-v7.22.3-2026-05-11.rsc
   • Trạng thái: OK

🔗 Xem Changelog | Tải về

✅ Đã tự động sao lưu xong, sẵn sàng cập nhật!
```

## 💡 Mẹo

### Đổi kênh cập nhật
```routeros
/system package update set channel=stable      # Bản ổn định (khuyến nghị)
/system package update set channel=long-term   # Bản hỗ trợ dài hạn
```

### Cập nhật router sau khi nhận thông báo
```routeros
# Script đã tự sao lưu, chỉ cần chạy:
/system package update install
# Router sẽ tự khởi động lại và cập nhật
```

### Import lại khi script được cập nhật
```routeros
# Script tự xóa bản cũ trước khi tạo mới:
/import file-name=mikrotik-check-update.rsc
```

### Dọn file backup cũ
```routeros
/file print where name~"backup"
/file remove [find name~"test-backup"]
```

## 📁 Files

| File | Mô tả |
|------|--------|
| `mikrotik-check-update.rsc` | Script RouterOS — import vào router |
| `README.md` | Hướng dẫn sử dụng |

## 📝 Yêu cầu

- MikroTik RouterOS **v7.x**
- Router có kết nối Internet (để check update và gửi Telegram)
- Telegram Bot Token & Chat ID
