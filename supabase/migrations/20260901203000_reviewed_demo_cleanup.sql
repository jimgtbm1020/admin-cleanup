-- Reviewed demo cleanup migration.
-- Scope is permanently allowlisted to BTC-2026-0001 and BTC-2026-0002.
-- Deployment and invocation require separate review/approval.

create schema if not exists private;

create or replace function private.demo_cleanup_authorized()
returns boolean
language plpgsql
stable
security definer
set search_path = public, private
as $$
begin
  return current_setting('app.demo_cleanup_token', true) = 'demo-cleanup-v1'
     and auth.uid() is not null
     and public.current_user_role() in ('admin', 'coordinator');
end;
$$;

revoke all on function private.demo_cleanup_authorized() from public, anon, authenticated;

-- Add a one-time, exact allowlist escape for the two named demo records.
create or replace function public.enforce_training_completion_integrity()
returns trigger
language plpgsql
set search_path = public, private
as $$
declare
  v_class_status text;
  v_elapsed_minutes integer;
begin
  if tg_op = 'DELETE' then
    if old.record_status = 'Finalized'
       and not (
         private.demo_cleanup_authorized()
         and old.completion_number in ('BTC-2026-0001', 'BTC-2026-0002')
       ) then
      raise exception 'Finalized completion records cannot be deleted.';
    end if;
    return old;
  end if;

  if tg_op = 'UPDATE' and old.record_status = 'Finalized' then
    if to_jsonb(new) is distinct from to_jsonb(old) then
      raise exception 'Finalized completion records are locked and cannot be edited.';
    end if;
    return new;
  end if;

  if new.record_status = 'Finalized' then
    select class_status into v_class_status
      from public.training_requests where id = new.request_id;

    if v_class_status is null then raise exception 'Training request not found.'; end if;
    if v_class_status not in ('Closed','Completed') then
      raise exception 'Close the class in Attendance before finalizing Completion.';
    end if;
    if new.actual_training_date is null then raise exception 'Actual training date is required before finalizing.'; end if;
    if new.actual_attendees is null then raise exception 'Actual attendance is required before finalizing.'; end if;
    if new.actual_minutes is null or new.actual_minutes <= 0 then
      raise exception 'Actual training duration must be greater than zero before finalizing.';
    end if;
    if (new.actual_start_time is null) <> (new.actual_end_time is null) then
      raise exception 'Actual start and end times must either both be entered or both be left blank.';
    end if;
    if new.actual_start_time is not null and new.actual_end_time is not null then
      v_elapsed_minutes := (((extract(epoch from (new.actual_end_time-new.actual_start_time))/60)::integer + 1440) % 1440);
      if v_elapsed_minutes <= 0 then
        raise exception 'Actual start and end times must define a positive training duration.';
      end if;
      if new.actual_minutes <> v_elapsed_minutes then
        raise exception 'Actual training duration must match the entered start and end times.';
      end if;
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.protect_training_request_deletion()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_role text;
begin
  v_role := public.current_user_role();

  if current_user = 'authenticated' and v_role not in ('admin','coordinator') then
    raise exception 'Administrator or coordinator access is required to delete a training request.';
  end if;

  if not (
    private.demo_cleanup_authorized()
    and old.request_number in ('BT-2026-0001', 'BT-2026-0003')
  ) and (
    old.class_status in ('Registration Open','In Progress','Closed','Completed','Archived')
    or old.class_started_at is not null
    or old.class_closed_at is not null
    or old.completed_at is not null
    or exists (select 1 from public.training_attendance_sessions s where s.request_id=old.id)
    or exists (select 1 from public.training_attendees a where a.request_id=old.id)
    or exists (select 1 from public.training_completion_records c where c.request_id=old.id)
  ) then
    raise exception 'This training request has operational or historical records and cannot be deleted. Preserve it in Training History instead.';
  end if;

  insert into public.administration_activity(actor_id, category, action, entity_type, entity_id, subject, details)
  values (auth.uid(), 'Requests', 'training_request_deleted', 'training_request', old.id::text,
    coalesce(old.request_number || ' — ' || old.agency_name, old.request_number, old.agency_name, 'Training Request'),
    jsonb_build_object('request_number', old.request_number, 'agency_name', old.agency_name,
      'status', old.status, 'class_status', old.class_status,
      'submission_source', old.submission_source, 'created_at', old.created_at));
  return old;
end;
$$;

create or replace function private.purge_demo_training_records()
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_request_ids uuid[];
  v_agency_ids uuid[];
  v_deleted integer;
  v_total integer := 0;
begin
  if not private.demo_cleanup_authorized() then
    raise exception 'Administrator authorization required.';
  end if;

  select array_agg(request_id), array_agg(distinct r.agency_id)
    into v_request_ids, v_agency_ids
    from public.training_completion_records c
    join public.training_requests r on r.id = c.request_id
   where c.completion_number in ('BTC-2026-0001', 'BTC-2026-0002');

  if coalesce(array_length(v_request_ids, 1), 0) = 0 then
    return jsonb_build_object('ok', true, 'deleted', false, 'message', 'Demo records already absent.');
  end if;

  delete from public.training_certificate_email_deliveries
   where request_id = any(v_request_ids);
  delete from public.training_material_distributions
   where request_id = any(v_request_ids);
  delete from public.training_email_delivery_events
   where queue_id in (select id from public.training_email_queue where notification_id in
     (select id from public.training_notifications where request_id = any(v_request_ids)));
  delete from public.training_email_queue
   where notification_id in (select id from public.training_notifications where request_id = any(v_request_ids));
  delete from public.training_material_access_events
   where share_id in (select id from public.training_material_share_links where request_id = any(v_request_ids));
  delete from public.training_material_share_items
   where share_id in (select id from public.training_material_share_links where request_id = any(v_request_ids));
  delete from public.training_material_share_links where request_id = any(v_request_ids);
  delete from public.training_class_materials where request_id = any(v_request_ids);
  delete from public.training_completion_modules where request_id = any(v_request_ids);
  delete from public.training_request_activity where request_id = any(v_request_ids);
  delete from public.training_notifications where request_id = any(v_request_ids);
  delete from public.training_attendees where request_id = any(v_request_ids);
  delete from public.training_attendance_sessions where request_id = any(v_request_ids);
  delete from public.training_signin_ingests where request_id = any(v_request_ids);
  delete from public.request_modules where request_id = any(v_request_ids);
  delete from public.public_training_request_links
   where id in (select public_request_link_id from public.training_requests where id = any(v_request_ids));
  delete from public.agency_portal_links
   where id in (select portal_link_id from public.training_requests where id = any(v_request_ids));
  delete from public.training_completion_records
   where completion_number in ('BTC-2026-0001', 'BTC-2026-0002');

  perform set_config('app.demo_cleanup_token', 'demo-cleanup-v1', true);
  delete from public.training_requests where id = any(v_request_ids);
  perform set_config('app.demo_cleanup_token', '', true);

  delete from public.training_people
   where agency_id = any(v_agency_ids)
     and not exists (select 1 from public.training_requests r where r.agency_id = training_people.agency_id);
  delete from public.agencies
   where id = any(v_agency_ids)
     and not exists (select 1 from public.training_requests r where r.agency_id = agencies.id);

  return jsonb_build_object('ok', true, 'deleted', true,
    'completion_numbers', jsonb_build_array('BTC-2026-0001','BTC-2026-0002'));
end;
$$;

revoke all on function private.purge_demo_training_records() from public, anon;
grant execute on function private.purge_demo_training_records() to authenticated;
