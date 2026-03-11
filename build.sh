#!/bin/bash

# Dừng toàn bộ script nếu có lệnh nào bị lỗi
set -e

echo "🛑 Đang dừng các container cũ..."
sudo docker compose down

echo "🗑️ Đang dọn dẹp các container và image cũ không sử dụng (để tránh rác hệ thống)..."
sudo docker system prune -af --volumes

echo "⚙️ Đang build lại image từ mã nguồn mới nhất..."
# Sử dụng tham số --no-cache để đảm bảo build lại code mới tinh từ đầu
sudo docker compose build --no-cache lavamusic

echo "🚀 Đang khởi động lại Bot và Lavalink ở chế độ tự động chạy ngầm (restart=always)..."
# Chạy cả lavamusic và lavalink local theo thiết lập của project
sudo docker compose --profile lavalink up -d

echo "========================================================"
echo "✅ Hoàn tất! BOT đã được cập nhật code mới và đang chạy."
echo "🔗 Để xem log của BOT, bạn có thể sử dụng lệnh sau:"
echo "sudo docker logs -f lavamusic"
echo ""
echo "🔗 Để xem log của Lavalink, dùng lệnh:"
echo "sudo docker logs -f lavamusic-lavalink"
echo "========================================================"
