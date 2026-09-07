-- FORM TẬP LUYỆN cho khách mới: lưu kinh nghiệm/môn thể thao và chấn thương
-- cùng lượt đặt lớp, để HLV nắm thể trạng trước buổi tập.
-- Chạy MỘT LẦN trong SQL Editor, sau supabase-schema.sql và supabase-member-check.sql.

alter table public.bookings add column if not exists experience text not null default '';
alter table public.bookings add column if not exists injuries   text not null default '';

-- book_class bản mới: thêm p_experience, p_injuries (mặc định rỗng nên lời gọi
-- cũ 3 tham số vẫn chạy). Bỏ bản cũ để không bị trùng tên hàm.
drop function if exists public.book_class(text, text, text);

create or replace function public.book_class(
  p_class_id text, p_name text, p_contact text,
  p_experience text default '', p_injuries text default ''
) returns json language plpgsql security definer set search_path = public as $$
declare
  v_capacity constant int := 8;
  v_date date; v_count int;
  v_mname text; v_ms date; v_me date;
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

  insert into public.bookings (class_id, class_date, name, contact, experience, injuries)
    values (p_class_id, v_date, trim(p_name), trim(p_contact),
            trim(coalesce(p_experience, '')), trim(coalesce(p_injuries, '')));

  select m.name, m.started_on, m.expires_on into v_mname, v_ms, v_me
    from public.members m
    where public.norm_contact(m.contact) = public.norm_contact(p_contact)
    order by m.expires_on desc
    limit 1;

  return json_build_object('ok', true,
    'member', case when v_me is null then null else json_build_object(
      'name', v_mname, 'started_on', v_ms, 'expires_on', v_me,
      'days_left', v_me - (now() at time zone 'Asia/Ho_Chi_Minh')::date
    ) end);
end $$;

grant execute on function public.book_class(text, text, text, text, text) to anon, authenticated;

-- Trang admin: trả thêm experience & injuries. Đổi cột trả về nên phải bỏ hàm cũ.
drop function if exists public.admin_list_bookings(text);

create or replace function public.admin_list_bookings(p_pin text)
returns table (id uuid, class_id text, class_date date, name text, contact text,
               experience text, injuries text, created_at timestamptz)
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform pg_sleep(0.3);
  if not public.admin_check_pin(p_pin) then
    raise exception 'unauthorized';
  end if;
  return query
    select b.id, b.class_id, b.class_date, b.name, b.contact,
           b.experience, b.injuries, b.created_at
    from bookings b
    order by b.class_date desc, b.created_at
    limit 500;
end $$;

revoke all on function public.admin_list_bookings(text) from public;
grant execute on function public.admin_list_bookings(text) to anon, authenticated;
