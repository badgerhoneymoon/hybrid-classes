# Elevate — Lớp học nhóm buổi chiều

Trang tĩnh một file (`index.html`) cho học viên xem lịch và đặt lớp chiều
Thứ 2 / Thứ 4 / Thứ 6 (17:00 và 18:15, tối đa 8 người mỗi lớp).

## Sửa nội dung & đưa lên mạng

Trang tự động deploy bằng GitHub Pages — chỉ cần push là lên mạng:

```bash
cd ~/Developer/Hybrid-classes
# ...sửa index.html...
git add -A && git commit -m "Mô tả thay đổi"
git push
```

Khoảng 1 phút sau, bản mới xuất hiện tại địa chỉ GitHub Pages của repo.
Không cần kéo-thả lên Vercel nữa.

## Bật đặt lớp dùng chung (Supabase) — làm một lần

Khi chưa cấu hình, trang chạy chế độ demo: lượt đặt chỉ lưu trên trình duyệt
của từng người. Để mọi người thấy chung một danh sách chỗ trống:

1. Tạo tài khoản miễn phí tại [supabase.com](https://supabase.com) → **New project**
   (đặt tên tuỳ ý, ví dụ `elevate-classes`; chọn region Singapore cho gần).
2. Vào **SQL Editor** → dán toàn bộ nội dung file `supabase-schema.sql` → **Run**.
3. Vào **Settings → API**, chép 2 giá trị:
   - **Project URL** (dạng `https://xxxx.supabase.co`)
   - **anon public key** (chuỗi dài bắt đầu bằng `eyJ...`)
4. Mở `index.html`, tìm `SUPABASE_URL` và `SUPABASE_ANON_KEY` (gần cuối file),
   dán 2 giá trị vào giữa cặp nháy `""`.
5. Commit và push (xem mục trên). Xong — chỗ trống giờ là dữ liệu chung,
   cập nhật theo thời gian thực cho tất cả mọi người.

Ghi chú:

- **anon key để công khai trong file là bình thường** — nó chỉ cho phép gọi
  2 hàm `book_class` / `list_bookings`; bảng dữ liệu gốc bị khoá (RLS).
- SĐT/email người đặt **không hiển thị công khai** — xem trong Supabase →
  **Table Editor → bookings** (cột `contact`).
- Lượt đặt gắn với **buổi gần nhất** của lớp (ví dụ đặt lớp Thứ 2 vào sáng
  Thứ 5 nghĩa là giữ chỗ cho Thứ 2 tuần sau). Sang tuần, danh sách tự trống lại.
- Muốn đổi sĩ số tối đa: sửa `CAPACITY` trong `index.html` **và** `v_capacity`
  trong `supabase-schema.sql` (chạy lại phần hàm `book_class` trong SQL Editor).
