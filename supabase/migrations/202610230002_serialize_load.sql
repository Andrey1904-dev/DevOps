-- Serialize load/projection with actions; preserve all user data and grants.
begin;
create or replace function public.academy_load() returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); s jsonb; rev bigint;
begin
 if uid is null then raise exception 'Нужен вход' using errcode='42501';end if;
 insert into public.academy_profiles(user_id) values(uid) on conflict do nothing;
 insert into public.academy_settings(user_id) values(uid) on conflict do nothing;
 insert into public.academy_state(user_id,body) values(uid,academy_private.initial_state()) on conflict do nothing;
 select body,revision into s,rev from public.academy_state where user_id=uid for update;
 perform academy_private.project_state(uid,s);
 return jsonb_build_object('state',s,'revision',rev);
end $$;
notify pgrst, 'reload schema';
commit;
