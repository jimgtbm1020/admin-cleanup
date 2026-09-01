create or replace function private.clear_demo_agency_contact_info()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $function$
declare
  v_agency_ids uuid[] := array[
    '97a0868b-012c-45aa-ba97-0adfee584e62'::uuid,
    '42ef6e66-31fc-4adb-a265-f66629a96f41'::uuid,
    'f75d4560-827d-4c30-bc11-c00ec64b5f24'::uuid
  ];
begin
  if not private.demo_cleanup_authorized() then
    raise exception 'Reviewed demo cleanup authorization required.';
  end if;

  update public.agencies
  set agency_address=null,
      city_state_zip=null,
      contact_person=null,
      contact_phone=null,
      contact_email=null,
      notes=null
  where id = any(v_agency_ids)
    and active=false;

  return jsonb_build_object(
    'ok', true,
    'mode', 'directory-contact-info-only',
    'agenciesProcessed', (
      select count(*) from public.agencies
      where id = any(v_agency_ids)
        and active=false
    ),
    'requestsPreserved', (
      select count(*) from public.training_requests
      where agency_id = any(v_agency_ids)
    ),
    'finalizedCompletionsPreserved', (
      select count(*)
      from public.training_completion_records c
      join public.training_requests r on r.id=c.request_id
      where r.agency_id = any(v_agency_ids)
        and c.record_status='Finalized'
    )
  );
end;
$function$;

create or replace function public.clear_demo_agency_contact_info()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $function$
begin
  if auth.uid() is null or public.current_user_role() not in ('admin','coordinator') then
    raise exception 'Administrator or coordinator access required.';
  end if;
  perform set_config('app.demo_cleanup_token','demo-cleanup-v1',true);
  return private.clear_demo_agency_contact_info();
end;
$function$;

revoke all on function public.clear_demo_agency_contact_info() from public;
grant execute on function public.clear_demo_agency_contact_info() to authenticated;