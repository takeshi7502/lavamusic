#!/bin/bash

# Dừng toàn bộ script nếu có lệnh nào bị lỗi
set -e

echo "========================================================"
echo "🔧 LavaMusic — Docker Build & Deploy Script"
echo "========================================================"

# Bước 1: Kiểm tra Docker đã cài chưa
if ! command -v docker &> /dev/null; then
    echo "❌ Docker chưa được cài đặt! Vui lòng cài Docker trước."
    echo "   Chạy: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose chưa được cài đặt!"
    exit 1
fi

echo "✅ Docker & Docker Compose đã sẵn sàng."

# Bước 2: Kiểm tra file .env có tồn tại không
if [ ! -f .env ]; then
    echo "❌ Không tìm thấy file .env! Hãy tạo file .env trước khi chạy build."
    exit 1
fi

echo "✅ File .env đã tồn tại."

# Bước 3: Tự động sửa NODES host thành "lavalink" cho Docker networking
# (trong Docker Compose, các container giao tiếp qua tên service, không phải localhost)
if grep -q '"host":"localhost"' .env 2>/dev/null; then
    echo "⚠️  Phát hiện NODES host đang là 'localhost', tự động đổi sang 'lavalink' cho Docker..."
    sed -i 's/"host":"localhost"/"host":"lavalink"/g' .env
    echo "✅ Đã cập nhật NODES host thành 'lavalink'."
fi

# Bước 5: Chuyển đổi line endings từ Windows (CRLF) sang Linux (LF)
# (Quan trọng khi code được viết trên Windows nhưng chạy trên Linux Docker)
echo "📝 Đang chuyển đổi line endings cho các file cấu hình..."
if command -v sed &> /dev/null; then
    sed -i 's/\r$//' ./Lavalink/application.yml 2>/dev/null || true
    sed -i 's/\r$//' ./entrypoint.sh 2>/dev/null || true
    sed -i 's/\r$//' ./.env 2>/dev/null || true
    echo "✅ Đã chuyển đổi line endings."
fi

# Bước 6: Phân quyền thư mục Lavalink cho container (user 322)
if [ -d "./Lavalink" ]; then
    echo "🔒 Đang phân quyền thư mục Lavalink..."
    sudo chown -R 322:322 ./Lavalink 2>/dev/null || true
    echo "✅ Đã phân quyền Lavalink."
fi

# Bước 5: Dừng container cũ
echo "🛑 Đang dừng các container cũ..."
sudo docker compose --profile lavalink down --remove-orphans 2>/dev/null || true

# Bước 6: Xoá volume lavamusic.db bị lỗi (nếu Docker đã tạo thành thư mục)
if [ -d "./lavamusic.db" ]; then
    echo "⚠️  Phát hiện lavamusic.db là thư mục (lỗi Docker mount cũ), đang xoá..."
    sudo rm -rf ./lavamusic.db
    echo "✅ Đã xoá thư mục lavamusic.db lỗi."
fi

# Bước 7: Xoá Docker BuildKit cache cũ (tránh lỗi snapshot hỏng)
echo "🧹 Đang xoá Docker build cache cũ..."
sudo docker builder prune -af 2>/dev/null || true

# Bước 8: Build lại image từ mã nguồn mới nhất
echo "⚙️  Đang build lại image từ mã nguồn mới nhất..."
if ! sudo docker compose build --no-cache lavamusic; then
    echo "❌ Build thất bại! Kiểm tra lại Dockerfile và mã nguồn."
    exit 1
fi
echo "✅ Build image thành công."

# Bước 8: Khởi động lại tất cả container
echo "🚀 Đang khởi động Bot và Lavalink..."
if ! sudo docker compose --profile lavalink up -d; then
    echo "❌ Khởi động container thất bại!"
    exit 1
fi

# Bước 9: Chờ vài giây rồi kiểm tra trạng thái
echo "⏳ Đang chờ container khởi động (10 giây)..."
sleep 10

# Kiểm tra trạng thái container
echo ""
echo "📋 Trạng thái các container:"
sudo docker ps -a --filter "name=lavamusic" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Kiểm tra bot có đang chạy không
if sudo docker ps --filter "name=lavamusic" --filter "status=running" --format "{{.Names}}" | grep -q "^lavamusic$"; then
    echo "========================================================"
    echo "✅ Hoàn tất! BOT đã sẵn sàng hoạt động."
    echo "🔗 Để xem log BOT:      sudo docker logs -f lavamusic"
    echo "🔗 Để xem log Lavalink: sudo docker logs -f lavamusic-lavalink"
    echo "========================================================"
else
    echo "========================================================"
    echo "⚠️  BOT có vẻ chưa chạy ổn định. Kiểm tra log để biết chi tiết:"
    echo "    sudo docker logs --tail 30 lavamusic"
    echo "========================================================"
fi
