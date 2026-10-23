-- All identities and evidence are synthetic; everything is rolled back.
begin;
do $$ begin
 if exists(select 1 from auth.users where id in ('34f6f994-7c3c-40d3-90cf-2b71ad261a11','34f6f994-7c3c-40d3-90cf-2b71ad261b22')) then
  raise exception 'Synthetic test IDs already exist; abort without touching them';
 end if;
end $$;
insert into auth.users(id) values('34f6f994-7c3c-40d3-90cf-2b71ad261a11'),('34f6f994-7c3c-40d3-90cf-2b71ad261b22');
set local role authenticated;
select set_config('request.jwt.claim.sub','34f6f994-7c3c-40d3-90cf-2b71ad261a11',true);
do $$
declare r jsonb; s jsonb; rev bigint; k text; aid text;
begin
 r:=public.academy_load();
 if r->'state'->'attempts'<>'[]'::jsonb then raise exception 'False initial progress';end if;
 r:=public.academy_action('note','{"text":"SYNTHETIC A ONLY"}',0);
 begin
  perform public.academy_action('note','{"text":"stale"}',0);raise exception 'Stale write accepted';
 exception when serialization_failure then null;end;
 begin
  perform public.academy_action('lesson_start','{"lesson":"paths"}',1);raise exception 'Practice opened too early';
 exception when invalid_parameter_value then null;end;
 r:=public.academy_action('diagnostic_start','{"confirmed":true}',1);rev:=2;
 foreach k in array array['terminal','linux','filesystem','networks','http_dns','git','bash','python','devops'] loop
  r:=public.academy_action('diagnostic_answer',jsonb_build_object('topic',k,'answer','SYNTHETIC ONLY - not learner evidence'),rev);rev:=rev+1;aid:=r->>'attempt_id';
  r:=public.academy_action('diagnostic_review',jsonb_build_object('topic',k,'attempt_id',aid,'rating','unknown','feedback','SYNTHETIC reviewer, no real assessment','confirmed',true),rev);rev:=rev+1;
 end loop;
 r:=public.academy_action('program_approve','{"confirmation":"УТВЕРЖДАЮ"}',rev);rev:=rev+1;
 r:=public.academy_action('lesson_start','{"lesson":"paths"}',rev);rev:=rev+1;
 r:=public.academy_action('hint','{"lesson":"paths"}',rev);rev:=rev+1;
 begin
  perform public.academy_action('hint','{"lesson":"paths"}',rev);raise exception 'Second hint opened without attempt';
 exception when invalid_parameter_value then null;end;
 r:=public.academy_action('attempt','{"lesson":"paths","answer":"/academy/notes/day1.txt","explanation":"SYNTHETIC explanation with sufficient length","mode":"hint"}',rev);rev:=rev+1;aid:=r->>'attempt_id';
 s:=public.academy_load()->'state';
 if s#>>'{lessons,paths,status}'<>'submitted' then raise exception 'Automatic completion';end if;
 r:=public.academy_action('review',jsonb_build_object('attempt_id',aid,'verdict','accepted','feedback','SYNTHETIC external review of this test attempt','confirmed',true),rev);rev:=rev+1;
 s:=public.academy_load()->'state';
 if s#>>'{lessons,paths,status}'<>'completed' then raise exception 'Confirmed review not saved';end if;
 r:=public.academy_action('attempt','{"lesson":"paths","answer":"/academy/notes/day1.txt","explanation":"SYNTHETIC explanation with sufficient length","mode":"solution"}',rev);rev:=rev+1;aid:=r->>'attempt_id';
 r:=public.academy_action('review',jsonb_build_object('attempt_id',aid,'verdict','accepted','feedback','SYNTHETIC external review of solution reading','confirmed',true),rev);
 s:=public.academy_load()->'state';
 if s#>>'{lessons,paths,status}'='completed' then raise exception 'Solution reading counted as completion';end if;
 if (select count(*) from public.academy_notes)<>1 then raise exception 'Own data missing';end if;
 if (select count(*) from public.academy_reviews)<>11 then raise exception 'Review history projection mismatch';end if;
end $$;
select set_config('request.jwt.claim.sub','34f6f994-7c3c-40d3-90cf-2b71ad261b22',true);
do $$ begin
 if (select count(*) from public.academy_notes)<>0 then raise exception 'Cross-user read';end if;
 if exists(select 1 from public.academy_state where user_id='34f6f994-7c3c-40d3-90cf-2b71ad261a11') then raise exception 'Forged filter reveals A';end if;
 begin
  update public.academy_state set revision=0 where user_id='34f6f994-7c3c-40d3-90cf-2b71ad261a11';raise exception 'Direct write granted';
 exception when insufficient_privilege then null;end;
 perform public.academy_load();
 begin
  perform public.academy_action('note','{"user_id":"34f6f994-7c3c-40d3-90cf-2b71ad261a11","text":"spoofed"}',0);raise exception 'Spoofed owner accepted';
 exception when invalid_parameter_value then null;end;
 begin
  insert into public.academy_notes values('34f6f994-7c3c-40d3-90cf-2b71ad261a11',999,'spoofed',now());raise exception 'Cross-user insert granted';
 exception when insufficient_privilege then null;end;
end $$;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
do $$ begin
 begin perform public.academy_load();raise exception 'Anonymous RPC granted';exception when insufficient_privilege then null;end;
 begin perform * from public.academy_notes;raise exception 'Anonymous SELECT granted';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
select 'passed: rollback-only synthetic isolation, writes, spoofing, revisions, progress, hints and history' as result;
