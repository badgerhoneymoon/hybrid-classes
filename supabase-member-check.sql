-- HỌC VIÊN TỰ XEM GÓI TẬP + POPUP NHẮC GIA HẠN KHI ĐẶT LỚP
-- Chạy MỘT LẦN trong SQL Editor, SAU supabase-schema.sql và supabase-members.sql.
--
-- Cách khớp: so SĐT/email người nhập với cột contact trong bảng members
-- (bỏ khoảng trắng, dấu chấm, không phân biệt hoa thường). Vì vậy khi admin
-- thêm thành viên, hãy điền đúng SĐT họ hay dùng để đặt lớp.

-- Chuẩn hoá chuỗi liên hệ để so khớp
create or replace function public.norm_contact(t text)
returns text language sql immutable as $$
  select lower(regexp_replace(coalesce(t, ''), '[^a-zA-Z0-9@+]', '', 'g'));
$$;

-- Học viên tra cứu gói tập của CHÍNH MÌNH bằng liên hệ đã đăng ký.
-- Chỉ trả về 1 dòng khớp chính xác — không liệt kê được người khác.
create or replace function public.my_membership(p_contact text)
returns table (name text, started_on date, expires_on date)
language plpgsql security definer set search_path = public as $$
begin
  perform pg_sleep(0.2);  -- làm chậm dò quét hàng loạt
  if length(public.norm_contact(p_contact)) < 5 then return; end if;
  return query
    select m.name, m.started_on, m.expires_on
    from members m
    where public.norm_contact(m.contact) = public.norm_contact(p_contact)
    order by m.expires_on desc
    limit 1;
end $$;
revoke all on function public.my_membership(text) from public;
grant execute on function public.my_membership(text) to anon, authenticated;

-- Đặt lớp (bản nâng cấp): giữ nguyên toàn bộ luật cũ (khoá sĩ số 8, chặn
-- trùng tên), THÊM: nếu liên hệ khớp một thành viên có gói thì đính kèm
-- thông tin gói vào kết quả để trang web hiện popup nhắc gia hạn.
create or replace function public.book_class(p_class_id text, p_name text, p_contact text)
returns json language plpgsql security definer set search_path = public as $$
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

  insert into public.bookings (class_id, class_date, name, contact)
    values (p_class_id, v_date, trim(p_name), trim(p_contact));

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
