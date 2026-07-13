-- TRANG QUẢN TRỊ (/admin.html) — chạy file này MỘT LẦN trong Supabase:
-- Dashboard → SQL Editor → dán toàn bộ → Run.
--
-- Sau đó BẮT BUỘC đặt mã PIN bằng một lệnh riêng (không nằm trong file này
-- vì repo công khai — xem README.md, mục "Trang quản trị"). Chưa đặt PIN
-- thì trang admin từ chối tất cả mọi người.

-- Bảng 1 dòng giữ mã PIN đã băm (bcrypt). RLS bật, không policy nào →
-- không ai đọc/ghi trực tiếp được, kể cả bằng key công khai.
create table if not exists public.admin_config (
  id boolean primary key default true,
  pin_hash text not null,
  constraint admin_config_single_row check (id)
);
alter table public.admin_config enable row level security;

create or replace function public.admin_check_pin(p_pin text)
returns boolean language plpgsql stable security definer set search_path = public, extensions as $$
declare h text;
begin
  select pin_hash into h from admin_config where id;
  return h is not null and crypt(coalesce(p_pin, ''), h) = h;
end $$;
revoke all on function public.admin_check_pin(text) from public, anon, authenticated;

-- Toàn bộ lượt đặt (kèm liên hệ) — chỉ khi PIN đúng. pg_sleep làm chậm dò mã.
create or replace function public.admin_list_bookings(p_pin text)
returns table (id uuid, class_id text, class_date date, name text, contact text, created_at timestamptz)
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform pg_sleep(0.3);
  if not public.admin_check_pin(p_pin) then
    raise exception 'unauthorized';
  end if;
  return query
    select b.id, b.class_id, b.class_date, b.name, b.contact, b.created_at
    from bookings b
    order by b.class_date desc, b.created_at
    limit 500;
end $$;

-- Xoá một lượt đặt (trả chỗ trống lại cho lớp).
create or replace function public.admin_delete_booking(p_pin text, p_id uuid)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare n int;
begin
  perform pg_sleep(0.3);
  if not public.admin_check_pin(p_pin) then
    raise exception 'unauthorized';
  end if;
  delete from bookings b where b.id = p_id;
  get diagnostics n = row_count;
  return json_build_object('ok', true, 'deleted', n);
end $$;

revoke all on function public.admin_list_bookings(text) from public;
revoke all on function public.admin_delete_booking(text, uuid) from public;
grant execute on function public.admin_list_bookings(text) to anon, authenticated;
grant execute on function public.admin_delete_booking(text, uuid) to anon, authenticated;
