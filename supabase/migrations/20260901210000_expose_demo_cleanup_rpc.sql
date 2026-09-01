-- Expose only the reviewed cleanup function through an authenticated RPC.
create or replace function public.run_demo_cleanup()
returns jsonb
language plpgsql
security invoker
set search_path = public, private
as $$
begin
  if auth.uid() is null or public.current_user_role() not in ('admin','coordinator') then
    raise exception 'Administrator or coordinator access required.';
  end if;
  perform set_config('app.demo_cleanup_token','demo-cleanup-v1',true);
  return private.purge_demo_training_records();
end;
$$;

revoke all on function public.run_demo_cleanup() from public, anon;
grant execute on function public.run_demo_cleanup() to authenticated;