-- ĐẶT LỚP DÙNG CHUNG — chạy file này MỘT LẦN trong Supabase:
-- Dashboard → SQL Editor → dán toàn bộ nội dung → Run.
--
-- Thiết kế: bảng bookings không mở quyền đọc/ghi trực tiếp cho khách (anon).
-- Mọi thao tác đi qua 2 hàm bên dưới, nhờ vậy số điện thoại/email của người
-- đặt KHÔNG lộ ra công khai — chỉ chủ phòng tập xem được trong Table Editor.

create extension if not exists pgcrypto;

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  class_id text not null,          -- mon1/mon2/wed1/wed2/fri1/fri2 (khớp index.html)
  class_date date not null,        -- ngày diễn ra buổi được đặt
  name text not null,
  contact text not null,           -- SĐT/email — chỉ hiển thị trong dashboard
  created_at timestamptz not null default now()
);

alter table public.bookings enable row level security;

-- Ngày diễn ra buổi TIẾP THEO của một lớp (mon*/wed*/fri* → Thứ 2/4/6, giờ VN).
-- Sau 18:15 của chính ngày đó thì tính sang tuần sau.
create or replace function public.next_class_date(p_class_id text)
returns date language plpgsql stable as $$
declare
  target int; today date; off int; occ date;
begin
  target := case
    when p_class_id like 'mon%' then 1
    when p_class_id like 'wed%' then 3
    when p_class_id like 'fri%' then 5
    else null end;
  if target is null then return null; end if;
  today := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  off := (target - extract(isodow from today)::int + 7) % 7;
  occ := today + off;
  if off = 0 and (now() at time zone 'Asia/Ho_Chi_Minh')::time >= time '18:15' then
    occ := occ + 7;
  end if;
  return occ;
end $$;

-- Danh sách đặt chỗ của các buổi sắp diễn ra — KHÔNG kèm thông tin liên hệ.
create or replace function public.list_bookings()
returns table (class_id text, class_date date, name text)
language sql stable security definer set search_path = public as $$
  select b.class_id, b.class_date, b.name
  from public.bookings b
  where b.class_date = public.next_class_date(b.class_id)
  order by b.created_at;
$$;

-- Đặt lớp: khoá theo (lớp, ngày) để không bao giờ vượt sĩ số kể cả khi nhiều
-- người bấm cùng lúc; chặn một tên đặt trùng cùng một buổi.
create or replace function public.book_class(p_class_id text, p_name text, p_contact text)
returns json language plpgsql security definer set search_path = public as $$
declare
  v_capacity constant int := 8;    -- sĩ số tối đa, khớp CAPACITY trong index.html
  v_date date; v_count int;
begin
  if length(trim(coalesce(p_name, ''))) < 1
     or length(trim(coalesce(p_contact, ''))) < 3 then
    return json_build_object('ok', false, 'error', 'invalid');
  end if;
  v_date := public.next_class_date(p_class_id);
  if v_date is null then
    return json_build_object('ok', false, 'error', 'invalid');
  end if;

  perform pg_advisory_xact_lock(hashtext(p_class_id || v_date::text));

  select count(*) into v_count from public.bookings
    where class_id = p_class_id and class_date = v_date;
  if v_count >= v_capacity then
    return json_build_object('ok', false, 'error', 'full');
  end if;

  if exists (select 1 from public.bookings
    where class_id = p_class_id and class_date = v_date
      and lower(trim(name)) = lower(trim(p_name))) then
    return json_build_object('ok', false, 'error', 'duplicate');
  end if;

  insert into public.bookings (class_id, class_date, name, contact)
    values (p_class_id, v_date, trim(p_name), trim(p_contact));
  return json_build_object('ok', true);
end $$;

revoke all on function public.book_class(text, text, text) from public;
revoke all on function public.list_bookings() from public;
grant execute on function public.book_class(text, text, text) to anon, authenticated;
grant execute on function public.list_bookings() to anon, authenticated;
