-- Synthetic identities only. Roll back every record and never use the owner's JWT.
begin;
do $$ begin
 if exists(select 1 from auth.users where id in ('34f6f994-7c3c-40d3-90cf-2b71ad261c33','34f6f994-7c3c-40d3-90cf-2b71ad261d44')) then raise exception 'Test ID already exists';end if;
end $$;
insert into auth.users(id) values('34f6f994-7c3c-40d3-90cf-2b71ad261c33'),('34f6f994-7c3c-40d3-90cf-2b71ad261d44');
set local role authenticated;
select set_config('request.jwt.claim.sub','34f6f994-7c3c-40d3-90cf-2b71ad261c33',true);
do $$ declare r jsonb;s jsonb;before_s jsonb;rev bigint;begin
 r:=public.academy_load();rev:=(r->>'revision')::bigint;
 r:=public.academy_action('diagnostic_start','{"confirmed":true}',rev);rev:=rev+1;
 r:=public.academy_action('diagnostic_answer','{"topic":"linux","answer":"SYNTHETIC preserved observation"}',rev);rev:=rev+1;
 before_s:=public.academy_load()->'state';
 r:=public.academy_action('route_select','{"route":"beginner"}',rev);rev:=rev+1;
 s:=public.academy_load()->'state';
 if s->'diagnostic'<>before_s->'diagnostic' or s->'attempts'<>before_s->'attempts' then raise exception 'Evidence changed';end if;
 if s#>'{program_history,0,program}'<>before_s->'program' then raise exception 'Draft history lost';end if;
 if jsonb_array_length(s->'program')<>30 or s#>>'{program,0,readiness}'<>'ready' then raise exception 'Canonical beginner plan missing';end if;
 begin perform public.academy_action('program_approve','{"confirmation":"УТВЕРЖДАЮ","program_version":0}',rev);raise exception 'Stale program approved';exception when invalid_parameter_value then null;end;
 begin perform public.academy_action('program_approve','{"confirmation":"да","program_version":1}',rev);raise exception 'Implicit approval';exception when invalid_parameter_value then null;end;
 begin perform public.academy_action('program_approve','{"confirmation":"УТВЕРЖДАЮ"}',rev);raise exception 'Unbound approval';exception when invalid_parameter_value then null;end;
 -- Change route without discarding any answers; diagnostic route must remain gated.
 r:=public.academy_action('route_select','{"route":"diagnostic"}',rev);rev:=rev+1;
 begin perform public.academy_action('program_approve','{"confirmation":"УТВЕРЖДАЮ","program_version":2}',rev);raise exception 'Incomplete diagnostic route accepted';exception when invalid_parameter_value then null;end;
 r:=public.academy_action('route_select','{"route":"beginner"}',rev);rev:=rev+1;
 s:=public.academy_load()->'state';
 r:=public.academy_action('program_save',jsonb_build_object('program',s->'program'),rev);rev:=rev+1;
 s:=public.academy_load()->'state';
 if (s->>'program_version')::int<>4 or s#>>'{program,0,lesson_id}'<>'paths' then raise exception 'Canonical fields lost';end if;
 r:=public.academy_action('program_approve','{"confirmation":"УТВЕРЖДАЮ","program_version":4}',rev);rev:=rev+1;
 begin perform public.academy_action('lesson_start','{"lesson":"files"}',rev);raise exception 'Skipped baseline verification';exception when invalid_parameter_value then null;end;
 r:=public.academy_action('lesson_start','{"lesson":"paths"}',rev);rev:=rev+1;
 s:=public.academy_load()->'state';
 if s#>>'{lessons,paths,status}'<>'in_progress' or jsonb_array_length(s->'attempts')<>0 then raise exception 'False learning progress';end if;
 if s->'diagnostic'<>before_s->'diagnostic' then raise exception 'False diagnostic results';end if;
 begin perform public.academy_action('route_select','{"route":"diagnostic"}',rev);raise exception 'Approved program overwritten';exception when invalid_parameter_value then null;end;
 if not exists(select 1 from public.academy_programs where learning_route='beginner' and program_version=4 and approved) then raise exception 'Projection missing route';end if;
end $$;
select set_config('request.jwt.claim.sub','34f6f994-7c3c-40d3-90cf-2b71ad261d44',true);
do $$ declare s jsonb;begin
 perform public.academy_load();
 perform public.academy_action('route_select','{"route":"beginner"}',0);
 perform public.academy_action('program_approve','{"confirmation":"УТВЕРЖДАЮ","program_version":1}',1);
 perform public.academy_action('lesson_start','{"lesson":"paths"}',2);
 s:=public.academy_load()->'state';
 if s->'diagnostic'<>'{}'::jsonb or s->'diagnostic_started'<>'false'::jsonb or s->'attempts'<>'[]'::jsonb then raise exception 'Invented exam or progress';end if;
 perform public.academy_action('diagnostic_start','{"confirmed":true}',3);
 perform public.academy_action('diagnostic_answer','{"topic":"linux","answer":"SYNTHETIC optional observation after approval"}',4);
 if (public.academy_load()->'state'->'program')<>s->'program' then raise exception 'Optional diagnostic changed approved plan';end if;
end $$;
reset role;
rollback;
select 'passed: beginner approval without nine checks, program versions, preserved evidence, optional diagnostic route, first lesson, projection; rolled back' as result;
