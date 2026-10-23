-- Additive, repeatable migration. No existing tables or data are dropped.
begin;
create schema if not exists academy_private;
revoke all on schema academy_private from public, anon, authenticated;

create table if not exists public.academy_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default '' check (length(display_name)<=120),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.academy_state (
 user_id uuid primary key references auth.users(id) on delete cascade,
 body jsonb not null check (jsonb_typeof(body)='object'),
 revision bigint not null default 0 check (revision>=0),
 updated_at timestamptz not null default now()
);
create table if not exists public.academy_diagnostic_attempts (
 user_id uuid not null references auth.users(id) on delete cascade,
 id text not null, topic text not null, answer text not null check(length(answer) between 1 and 8000),
 submitted_at timestamptz not null, primary key(user_id,id)
);
create index if not exists academy_diagnostic_topic on public.academy_diagnostic_attempts(user_id,topic,submitted_at);
create table if not exists public.academy_programs (
 user_id uuid primary key references auth.users(id) on delete cascade,
 slots jsonb not null check(jsonb_typeof(slots)='array' and jsonb_array_length(slots)=30),
 approved boolean not null default false, approved_at timestamptz,
 updated_at timestamptz not null default now(), check(not approved or approved_at is not null)
);
create table if not exists public.academy_lesson_progress (
 user_id uuid not null references auth.users(id) on delete cascade, lesson_id text not null,
 status text not null check(status in ('in_progress','submitted','needs_correction','completed')),
 hint_level integer not null default 0 check(hint_level between 0 and 2),
 assistance text check(assistance in ('independent','hint','solution','retest')),
 updated_at timestamptz not null default now(), primary key(user_id,lesson_id)
);
create table if not exists public.academy_attempts (
 user_id uuid not null references auth.users(id) on delete cascade, id text not null, lesson_id text not null,
 answer text not null check(length(answer) between 1 and 8000),
 explanation text not null check(length(explanation) between 15 and 8000),
 assistance text not null check(assistance in ('independent','hint','solution','retest')),
 hint_level integer not null check(hint_level between 0 and 2),
 artifact_check text not null check(artifact_check in ('manual','match','mismatch')),
 submitted_at timestamptz not null, primary key(user_id,id),
 foreign key(user_id,lesson_id) references public.academy_lesson_progress(user_id,lesson_id) on delete cascade
);
create index if not exists academy_attempt_lesson on public.academy_attempts(user_id,lesson_id,submitted_at);
create table if not exists public.academy_reviews (
 user_id uuid not null references auth.users(id) on delete cascade, attempt_id text not null,
 kind text not null check(kind in ('diagnostic','lesson')), result text not null,
 feedback text not null check(length(feedback) between 12 and 8000),
 source text not null, reviewed_at timestamptz not null, primary key(user_id,kind,attempt_id)
);
create table if not exists public.academy_repetition (
 user_id uuid not null references auth.users(id) on delete cascade, topic_id text not null,
 reason text not null, active boolean not null default true,
 updated_at timestamptz not null default now(), primary key(user_id,topic_id)
);
create table if not exists public.academy_notes (
 user_id uuid not null references auth.users(id) on delete cascade, ordinal integer not null check(ordinal>=0),
 body text not null check(length(body) between 1 and 4000), created_at timestamptz not null,
 primary key(user_id,ordinal)
);
create table if not exists public.academy_settings (
 user_id uuid primary key references auth.users(id) on delete cascade,
 preferences jsonb not null default '{"language":"ru","theme":"dark"}'::jsonb,
 updated_at timestamptz not null default now()
);
create table if not exists public.academy_events (
 user_id uuid not null references auth.users(id) on delete cascade, ordinal integer not null,
 action text not null, occurred_at timestamptz not null, primary key(user_id,ordinal)
);

-- RLS on every personal table, even though clients receive SELECT only.
-- Writes are transactional RPCs checking auth.uid(), not arbitrary snapshots.
do $policies$
declare t text;
begin
 foreach t in array array['academy_profiles','academy_state','academy_diagnostic_attempts','academy_programs',
 'academy_lesson_progress','academy_attempts','academy_reviews','academy_repetition','academy_notes','academy_settings','academy_events'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from public, anon, authenticated',t);
  execute format('grant select on public.%I to authenticated',t);
  if not exists(select 1 from pg_policies where schemaname='public' and tablename=t and policyname='academy_own_rows') then
   execute format('create policy academy_own_rows on public.%I to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id)',t);
  end if;
 end loop;
end $policies$;

create or replace function academy_private.require(ok boolean, message text) returns void
language plpgsql set search_path='' as $$ begin
 if ok is distinct from true then raise exception '%',message using errcode='22023'; end if;
end $$;
create or replace function academy_private.str(p jsonb,k text,mi integer default 1,ma integer default 8000) returns text
language plpgsql set search_path='' as $$ declare v text; begin
 perform academy_private.require(jsonb_typeof(p->k)='string',k||': ожидается строка');
 v=btrim(p->>k); perform academy_private.require(length(v) between mi and ma,k||': неверная длина'); return v;
end $$;
create or replace function academy_private.diagnostic_complete(s jsonb) returns boolean
language sql immutable set search_path='' as $$
 select not exists(select 1 from unnest(array['terminal','linux','filesystem','networks','http_dns','git','bash','python','devops']) k
 where s#>array['diagnostic',k,'-1','review'] is null);
$$;
create or replace function academy_private.initial_state() returns jsonb
language sql immutable set search_path='' as $$ select '{"schema": 1, "diagnostic_started": false, "diagnostic": {}, "lessons": {}, "attempts": [], "events": [], "notes": [], "program": [{"day": 1, "topic": "Ориентация и диагностика", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 2, "topic": "Терминал", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 3, "topic": "Пути", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 4, "topic": "Файлы и каталоги", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 5, "topic": "Просмотр и поиск", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 6, "topic": "Права доступа", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 7, "topic": "Процессы", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 8, "topic": "Службы Linux: модель", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 9, "topic": "Сети", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 10, "topic": "DNS и HTTP", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 11, "topic": "SSH: принципы", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 12, "topic": "Git: снимки", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 13, "topic": "Git: ветки", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 14, "topic": "Bash: аргументы", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 15, "topic": "Bash: ошибки", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 16, "topic": "Python: повторение", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 17, "topic": "Python: автоматизация", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 18, "topic": "Повторение и перенос", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 19, "topic": "Docker: принципы", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 20, "topic": "Dockerfile: разбор", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 21, "topic": "Compose: модель", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 22, "topic": "CI/CD: этапы", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 23, "topic": "GitHub Actions: чтение", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 24, "topic": "CI: права и секреты", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 25, "topic": "Логи", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 26, "topic": "Мониторинг", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 27, "topic": "DevSecOps: основы", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 28, "topic": "Практический проект: план", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 29, "topic": "Практический проект: проверка", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}, {"day": 30, "topic": "Объяснение проекта и собеседование", "hours": "2–4", "note": "Черновой слот; уточнить после диагностики"}], "program_approved": false}'::jsonb $$;

create or replace function academy_private.transform(s jsonb,act text,p jsonb) returns jsonb
language plpgsql set search_path='' as $$
declare
 k text; id text; v jsonb; a jsonb; h jsonb; r jsonb; note text; mode text; chk text; answer text;
 expl text; feedback text; level integer; idx integer; total integer; j integer; slots jsonb:='[]';
 stamp text:=to_char(clock_timestamp() at time zone 'utc','YYYY-MM-DD"T"HH24:MI:SS.US"Z"');
 result jsonb:='{}';
begin
 perform academy_private.require(jsonb_typeof(p)='object','Ожидается объект');
 perform academy_private.require(not p ? 'user_id','user_id задаётся только сервером');
 if act='diagnostic_start' then
  perform academy_private.require(p->'confirmed'='true'::jsonb,'Нужно явное решение начать');
  perform academy_private.require(not (s->>'diagnostic_started')::boolean,'Диагностика уже начата');
  s:=jsonb_set(s,'{diagnostic_started}','true');
 elsif act in ('diagnostic_answer','diagnostic_review') then
  perform academy_private.require((s->>'diagnostic_started')::boolean and not (s->>'program_approved')::boolean,'Диагностика не открыта или её снимок уже закрыт');
  k:=academy_private.str(p,'topic',1,40);
  perform academy_private.require(k=any(array['terminal','linux','filesystem','networks','http_dns','git','bash','python','devops']),'Неизвестная тема');
  h:=coalesce(s#>array['diagnostic',k],'[]');
  if act='diagnostic_answer' then
   answer:=academy_private.str(p,'answer'); id:=replace(gen_random_uuid()::text,'-','');
   h:=h||jsonb_build_array(jsonb_build_object('id',id,'answer',answer,'at',stamp)); result:=jsonb_build_object('attempt_id',id);
  else
   id:=academy_private.str(p,'attempt_id');mode:=academy_private.str(p,'rating');
   perform academy_private.require(h->-1->>'id'=id and h->-1->'review' is null,'Нужна последняя непроверенная попытка');
   perform academy_private.require(p->'confirmed'='true'::jsonb,'Подтвердите перенос внешней проверки');
   perform academy_private.require(mode=any(array['independent','support','unknown']),'Неизвестная оценка');
   feedback:=academy_private.str(p,'feedback',12);
   r:=jsonb_build_object('rating',mode,'feedback',feedback,'source','Внешняя проверка, подтверждённая пользователем','at',stamp);
   h:=jsonb_set(h,array[(jsonb_array_length(h)-1)::text,'review'],r);
  end if;
  s:=jsonb_set(s,array['diagnostic',k],h);
 elsif act='program_save' then
  perform academy_private.require(not (s->>'program_approved')::boolean,'Программа уже утверждена');
  perform academy_private.require(jsonb_typeof(p->'program')='array' and jsonb_array_length(p->'program')=30,'Нужно 30 слотов');
  j:=0;
  for v in select value from jsonb_array_elements(p->'program') loop
   j:=j+1; slots:=slots||jsonb_build_array(jsonb_build_object('day',j,'topic',academy_private.str(v,'topic',1,180),'note',academy_private.str(v,'note',1,500),'hours','2–4'));
  end loop;
  s:=jsonb_set(s,'{program}',slots);
 elsif act='program_approve' then
  perform academy_private.require(not (s->>'program_approved')::boolean and academy_private.diagnostic_complete(s),'Нужна проверка девяти тем; программа не должна быть уже утверждена');
  perform academy_private.require(p->>'confirmation'='УТВЕРЖДАЮ','Нужно явное утверждение');
  s:=s||jsonb_build_object('program_approved',true,'program_approved_at',stamp);
 elsif act in ('lesson_start','hint','attempt') then
  k:=academy_private.str(p,'lesson',1,40);
  perform academy_private.require(k=any(array['paths','files','read','search','permissions','processes','bash','git','network','python']),'Неизвестное задание');
  perform academy_private.require((s->>'program_approved')::boolean,'Сначала диагностика и утверждение программы');
  v:=s#>array['lessons',k];
  if act='lesson_start' then
   perform academy_private.require(v is null,'Задание уже начато');v:='{"status":"in_progress","hint_level":0}';
  else
   perform academy_private.require(v is not null,'Сначала начните задание');level:=(v->>'hint_level')::integer;
   if act='hint' then
    perform academy_private.require(level<2 and v->>'status'<>'completed','Подсказки недоступны');
    perform academy_private.require(level=0 or exists(select 1 from jsonb_array_elements(s->'attempts') x where x->>'lesson'=k and (x->>'hint_level')::int>=level),'После подсказки нужна собственная попытка');
    v:=jsonb_set(v,'{hint_level}',to_jsonb(level+1));
   else
    answer:=academy_private.str(p,'answer');expl:=academy_private.str(p,'explanation',15);mode:=academy_private.str(p,'mode');
    perform academy_private.require(mode=any(array['independent','hint','solution','retest']),'Неизвестный характер помощи');
    perform academy_private.require(level=0 or mode<>'independent','Подсказки уже использованы');
    chk:='manual';
    if k='paths' then chk:=case when btrim(split_part(answer,E'\n',1))='/academy/notes/day1.txt' then 'match' else 'mismatch' end; end if;
    id:=replace(gen_random_uuid()::text,'-','');
    a:=jsonb_build_object('id',id,'lesson',k,'answer',answer,'explanation',expl,'mode',mode,'hint_level',level,'check',chk,'at',stamp,'review',null);
    s:=jsonb_set(s,'{attempts}',(s->'attempts')||jsonb_build_array(a));
    v:=v||jsonb_build_object('status',case when chk='mismatch' then 'needs_correction' else 'submitted' end,'mode',mode);
    result:=jsonb_build_object('attempt_id',id,'check',chk);
   end if;
  end if;
  s:=jsonb_set(s,array['lessons',k],v);
 elsif act='review' then
  id:=academy_private.str(p,'attempt_id');idx:=-1;total:=jsonb_array_length(s->'attempts');
  for j in 0..total-1 loop
   if s->'attempts'->j->>'id'=id then idx:=j; end if;
  end loop;
  perform academy_private.require(idx>=0,'Попытка не найдена');a:=s->'attempts'->idx;k:=a->>'lesson';
  perform academy_private.require(not exists(select 1 from jsonb_array_elements(s->'attempts') with ordinality x(value,n) where n>idx+1 and value->>'lesson'=k),'Нужна последняя попытка');
  perform academy_private.require(a->'review'='null'::jsonb,'Попытка уже проверена');
  perform academy_private.require(p->'confirmed'='true'::jsonb,'Подтвердите реальную проверку');
  mode:=academy_private.str(p,'verdict');perform academy_private.require(mode=any(array['accepted','revise']),'Неизвестный вердикт');
  feedback:=academy_private.str(p,'feedback',15);
  perform academy_private.require(mode<>'accepted' or a->>'check'<>'mismatch','Сначала исправьте несовпадение артефакта');
  r:=jsonb_build_object('verdict',mode,'feedback',feedback,'source','Внешняя проверка, подтверждённая пользователем','at',stamp);
  s:=jsonb_set(s,array['attempts',idx::text,'review'],r);
  s:=jsonb_set(s,array['lessons',k,'status'],to_jsonb(case when mode='accepted' and a->>'mode' in ('independent','hint') then 'completed' else 'needs_correction' end));
 elsif act='note' then
  note:=academy_private.str(p,'text',1,4000);s:=jsonb_set(s,'{notes}',(s->'notes')||jsonb_build_array(jsonb_build_object('text',note,'at',stamp)));
 else raise exception 'Неизвестное действие' using errcode='22023';
 end if;
 s:=jsonb_set(s,'{events}',(s->'events')||jsonb_build_array(jsonb_build_object('action',act,'at',stamp)));
 return jsonb_build_object('state',s,'result',result);
end $$;

create or replace function academy_private.project_state(uid uuid,s jsonb) returns void
language plpgsql set search_path='' as $$
declare k text; v jsonb; a jsonb; r jsonb; n integer;
begin
 insert into public.academy_programs(user_id,slots,approved,approved_at) values(uid,s->'program',(s->>'program_approved')::boolean,(s->>'program_approved_at')::timestamptz)
 on conflict(user_id) do update set slots=excluded.slots,approved=excluded.approved,approved_at=excluded.approved_at,updated_at=now();
 for k,v in select * from jsonb_each(s->'lessons') loop
  insert into public.academy_lesson_progress values(uid,k,v->>'status',(v->>'hint_level')::int,v->>'mode',now())
  on conflict(user_id,lesson_id) do update set status=excluded.status,hint_level=excluded.hint_level,assistance=excluded.assistance,updated_at=now();
  insert into public.academy_repetition values(uid,'lesson:'||k,coalesce(v->>'mode',v->>'status'),v->>'status'='needs_correction' or coalesce(v->>'mode','independent')<>'independent',now())
  on conflict(user_id,topic_id) do update set reason=excluded.reason,active=excluded.active,updated_at=now();
 end loop;
 for a in select value from jsonb_array_elements(s->'attempts') loop
  insert into public.academy_attempts values(uid,a->>'id',a->>'lesson',a->>'answer',a->>'explanation',a->>'mode',(a->>'hint_level')::int,a->>'check',(a->>'at')::timestamptz)
  on conflict(user_id,id) do nothing;
  r:=a->'review';
  if r is not null and r<>'null'::jsonb then
   insert into public.academy_reviews values(uid,a->>'id','lesson',r->>'verdict',r->>'feedback',r->>'source',(r->>'at')::timestamptz) on conflict do nothing;
  end if;
 end loop;
 for k,v in select * from jsonb_each(s->'diagnostic') loop
  for a in select value from jsonb_array_elements(v) loop
   insert into public.academy_diagnostic_attempts values(uid,a->>'id',k,a->>'answer',(a->>'at')::timestamptz) on conflict do nothing;
   r:=a->'review';
   if r is not null and r<>'null'::jsonb then
    insert into public.academy_reviews values(uid,a->>'id','diagnostic',r->>'rating',r->>'feedback',r->>'source',(r->>'at')::timestamptz) on conflict do nothing;
   end if;
  end loop;
  r:=v->-1->'review';
  insert into public.academy_repetition values(uid,'diagnostic:'||k,coalesce(r->>'rating','unreviewed'),coalesce(r->>'rating' in ('support','unknown'),false),now())
  on conflict(user_id,topic_id) do update set reason=excluded.reason,active=excluded.active,updated_at=now();
 end loop;
 n:=0;for v in select value from jsonb_array_elements(s->'notes') loop
  insert into public.academy_notes values(uid,n,v->>'text',(v->>'at')::timestamptz) on conflict do nothing;n:=n+1;
 end loop;
 n:=0;for v in select value from jsonb_array_elements(s->'events') loop
  insert into public.academy_events values(uid,n,v->>'action',(v->>'at')::timestamptz) on conflict do nothing;n:=n+1;
 end loop;
end $$;

create or replace function public.academy_load() returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); s jsonb; rev bigint;
begin
 if uid is null then raise exception 'Нужен вход' using errcode='42501';end if;
 insert into public.academy_profiles(user_id) values(uid) on conflict do nothing;
 insert into public.academy_settings(user_id) values(uid) on conflict do nothing;
 insert into public.academy_state(user_id,body) values(uid,academy_private.initial_state()) on conflict do nothing;
 select body,revision into s,rev from public.academy_state where user_id=uid;
 perform academy_private.project_state(uid,s);
 return jsonb_build_object('state',s,'revision',rev);
end $$;
create or replace function public.academy_action(action text,payload jsonb,expected_revision bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); s jsonb; rev bigint; transformed jsonb;
begin
 if uid is null then raise exception 'Нужен вход' using errcode='42501';end if;
 select body,revision into s,rev from public.academy_state where user_id=uid for update;
 if not found then raise exception 'Сначала загрузите кабинет' using errcode='22023';end if;
 if expected_revision is distinct from rev then raise exception 'Данные изменились в другой вкладке. Обновите страницу перед повторной отправкой.' using errcode='40001';end if;
 transformed:=academy_private.transform(s,action,payload);s:=transformed->'state';
 update public.academy_state set body=s,revision=revision+1,updated_at=now() where user_id=uid;
 perform academy_private.project_state(uid,s);
 return (transformed->'result')||jsonb_build_object('revision',rev+1);
end $$;
revoke all on all functions in schema academy_private from public,anon,authenticated;
revoke all on function public.academy_load() from public,anon;
revoke all on function public.academy_action(text,jsonb,bigint) from public,anon;
grant execute on function public.academy_load() to authenticated;
grant execute on function public.academy_action(text,jsonb,bigint) to authenticated;
notify pgrst, 'reload schema';
commit;
