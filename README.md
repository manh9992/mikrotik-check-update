# 🔍 MikroTik RouterOS 7 - Auto Check Update & Telegram Notify

Script **chạy trực tiếp trên router MikroTik**, tự động kiểm tra phiên bản mới RouterOS 7, **backup cấu hình** và gửi thông báo qua Telegram.

## ✨ Tính năng

- ✅ Chạy **native trên RouterOS**
- ✅ Dùng `/system package update check-for-updates` (API chính thức)
- ✅ **Auto backup** khi có bản mới (binary `.backup` + text export `.rsc`)
- ✅ Gửi thông báo Telegram kèm thông tin router & trạng thái backup
- ✅ Scheduler tự động chạy lúc **5h sáng mỗi ngày**
- ✅ Script test giả lập có bản mới để kiểm tra toàn bộ flow
- ✅ Log đầy đủ trong `/log`

## 📋 Flow hoạt động

```
Scheduler (5h sáng mỗi ngày)
    │
    ▼
Kiểm tra update từ MikroTik server
    │
    ├── Không có bản mới → Ghi log, kết thúc
    │
    └── CÓ bản mới →
            │
            ├── 1. Auto backup (binary .backup)
            ├── 2. Auto export (text .rsc)
            └── 3. Gửi Telegram thông báo
                    (kèm thông tin router + trạng thái backup)
```

## 🚀 Cài đặt

### Bước 1: Tạo Telegram Bot

1. Mở Telegram, chat với [@BotFather](https://t.me/BotFather)
2. Gõ `/newbot` → đặt tên → nhận **Bot Token**
3. Chat với bot vừa tạo, gõ `/start`
4. Truy cập `https://api.telegram.org/bot<TOKEN>/getUpdates` → lấy **Chat ID**

> 💡 Nếu gửi vào group: thêm bot vào group, gõ tin nhắn bất kỳ, rồi xem getUpdates để lấy chat ID (số âm cho group chat, ví dụ `-92472379494593`)

### Bước 2: Sửa Bot Token & Chat ID trong file script

Mở file `mikrotik-check-update.rsc`, tìm và sửa **2 chỗ** (script chính + script test):

```
:local botToken "YOUR_BOT_TOKEN_HERE"    ← Thay bằng token thật
:local chatId "YOUR_CHAT_ID_HERE"        ← Thay bằng chat ID thật
```

### Bước 3: Import lên router

**Cách 1 - Upload file:**
1. Mở Winbox → Files → kéo thả file `mikrotik-check-update.rsc` vào
2. Mở Terminal, chạy:
```
/import file-name=mikrotik-check-update.rsc
```

**Cách 2 - Copy/Paste:**
1. Mở Winbox/WebFig → Terminal
2. Copy toàn bộ nội dung file → Paste vào Terminal

### Bước 4: Test

```
# Test toàn bộ flow (backup + gửi Telegram)
/system script run test-check-update

# Kiểm tra file backup đã tạo
/file print where name~"test-backup"

# Xóa file backup test sau khi kiểm tra xong
/file remove [find name~"test-backup"]
```

## 📦 Scripts được cài đặt

| Script | Mô tả |
|--------|--------|
| `check-routeros-update` | Script chính - kiểm tra update, backup, gửi Telegram |
| `test-check-update` | Script test - giả lập có bản mới v7.99.0, backup thật, gửi Telegram |
| `schedule-check-update` | Scheduler - chạy script chính lúc 05:00 mỗi ngày |

## 📖 Quản lý

### Xem script đã cài
```
/system script print where name~"update"
```

### Xem scheduler
```
/system scheduler print where name="schedule-check-update"
```

### Chạy thủ công (kiểm tra update thật)
```
/system script run check-routeros-update
```

### Tạm dừng / bật lại scheduler
```
# Tạm dừng
/system scheduler set schedule-check-update disabled=yes

# Bật lại
/system scheduler set schedule-check-update disabled=no
```

### Đổi giờ chạy (ví dụ 6h sáng)
```
/system scheduler set schedule-check-update start-time=06:00:00
```

### Sửa Bot Token hoặc Chat ID sau khi import
```
/system script edit check-routeros-update source
/system script edit test-check-update source
```
> Nhấn **Ctrl+O** để lưu, **Ctrl+X** để thoát editor.

### Gỡ cài đặt hoàn toàn
```
/system scheduler remove schedule-check-update
/system script remove check-routeros-update
/system script remove test-check-update
```

### Xóa file backup cũ (dọn dẹp)
```
# Xem danh sách backup
/file print where name~"backup"

# Xóa backup test
/file remove [find name~"test-backup"]

# Xóa backup cũ cụ thể
/file remove "backup-v7.22.3-2026-05-11.backup"
```

## 📩 Mẫu thông báo Telegram

### Khi có bản cập nhật mới (script chính)

```
🔔 RouterOS - Phiên Bản Mới!

🖥 Router: MikroTik-Home
📋 Model: RB5009UPr+S+ (arm64)
⏰ Uptime: 45d 12:30:00

📦 Phiên bản hiện tại: 7.22.3
🆕 Phiên bản mới: 7.23.0
🔀 Channel: stable

📊 Tình trạng router:
   • CPU: 12%
   • Free RAM: 78%

💾 Auto Backup:
   • File: backup-v7.22.3-2026-05-11.backup
   • Export: backup-v7.22.3-2026-05-11.rsc
   • Trạng thái: OK

🔗 Xem Changelog | Download

✅ Đã tự động backup xong, sẵn sàng update!
```

### Tin nhắn test (script test)

Giống như trên nhưng:
- Version mới hiển thị là `7.99.0` (fake)
- File backup có prefix `test-backup-v...`
- Cuối tin nhắn có dòng: **⚠️ ĐÂY LÀ TIN NHẮN TEST - KHÔNG PHẢI UPDATE THẬT!**

## 💡 Mẹo

### Đổi update channel
```
# Dùng stable (khuyến nghị)
/system package update set channel=stable

# Dùng long-term (ổn định hơn)
/system package update set channel=long-term
```

### Update router sau khi nhận thông báo
```
# Script đã tự backup rồi, chỉ cần chạy:
/system package update install

# Router sẽ tự reboot và cập nhật
```

### Re-import khi script được cập nhật
Script có sẵn lệnh xóa cũ trước khi tạo mới, nên chỉ cần:
```
# Upload file mới lên router, rồi:
/import file-name=mikrotik-check-update.rsc
```

## 📁 Files

| File | Mô tả |
|------|--------|
| `mikrotik-check-update.rsc` | Script RouterOS - import vào router |
| `README.md` | File hướng dẫn này |
