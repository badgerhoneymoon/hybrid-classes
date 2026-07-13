-- THEO DÕI GÓI TẬP (tab "Gói tập" trong /admin.html) — chạy MỘT LẦN trong
-- Supabase SQL Editor, SAU khi đã chạy supabase-admin.sql (cần hàm kiểm tra PIN).

-- Danh sách thành viên và hạn gói tập. RLS bật, không policy nào →
-- chỉ đọc/ghi được qua các hàm admin bên dưới (yêu cầu PIN đúng).
create table if not exists public.members (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  contact text not null default '',
  note text not null default '',          -- gói gì, giá nào... tuỳ ghi
  started_on date not null,
  expires_on date not null,
  created_at timestamptz not null default now()
);
alter table public.members enable row level security;

create or replace function public.admin_list_members(p_pin text)
returns table (id uuid, name text, contact text, note text, started_on date, expires_on date)
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform pg_sleep(0.3);
  if not public.admin_check_pin(p_pin) then raise exception 'unauthorized'; end if;
  return query
    select m.id, m.name, m.contact, m.note, m.started_on, m.expires_on
    from members m
    order by m.expires_on, m.name
    limit 1000;
end $$;

create or replace function public.admin_add_member(
  p_pin text, p_name text, p_contact text, p_note text,
  p_started_on date, p_expires_on date
) returns json language plpgsql security definer set search_path = public, extensions as $$
begin
  perform pg_sleep(0.3);
  if not public.admin_check_pin(p_pin) then raise exception 'unauthorized'; end if;
  if length(trim(coalesce(p_name, ''))) < 1 or p_expires_on is null or p_started_on is null then
    return json_build_object('ok', false, 'error', 'invalid');
  end if;
  insert into members (name, contact, note, started_on, expires_on)
    values (trim(p_name), trim(coalesce(p_contact, '')), trim(coalesce(p_note, '')),
            p_started_on, p_expires_on);
  return json_build_object('ok', true);
end $$;

-- Gia hạn: cộng thêm p_months tháng tính từ ngày hết hạn (nếu còn hạn)
-- hoặc từ hôm nay (nếu đã hết hạn từ trước).
create or replace function public.admin_extend_member(p_pin text, p_id uuid, p_months int default 1)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare v_new date;
begin
  perform pg_sleep(0.3);
  if not public.admin_check_pin(p_pin) then raise exception 'unauthorized'; end if;
  update members m
    set expires_on = (greatest(m.expires_on, (now() at time zone 'Asia/Ho_Chi_Minh')::date)
                      + make_interval(months => greatest(p_months, 1)))::date
    where m.id = p_id
    returning m.expires_on into v_new;
  if v_new is null then
    return json_build_object('ok', false, 'error', 'not_found');
  end if;
  return json_build_object('ok', true, 'expires_on', v_new);
end $$;

create or replace function public.admin_delete_member(p_pin text, p_id uuid)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare n int;
begin
  perform pg_sleep(0.3);
  if not public.admin_check_pin(p_pin) then raise exception 'unauthorized'; end if;
  delete from members m where m.id = p_id;
  get diagnostics n = row_count;
  return json_build_object('ok', true, 'deleted', n);
end $$;

revoke all on function public.admin_list_members(text) from public;
revoke all on function public.admin_add_member(text, text, text, text, date, date) from public;
revoke all on function public.admin_extend_member(text, uuid, int) from public;
revoke all on function public.admin_delete_member(text, uuid) from public;
grant execute on function public.admin_list_members(text) to anon, authenticated;
grant execute on function public.admin_add_member(text, text, text, text, date, date) to anon, authenticated;
grant execute on function public.admin_extend_member(text, uuid, int) to anon, authenticated;
grant execute on function public.admin_delete_member(text, uuid) to anon, authenticated;
