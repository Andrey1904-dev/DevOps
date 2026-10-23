"""Generate a reviewable additive migration from existing state machine, not learner data."""
from pathlib import Path
import json
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from curriculum import BEGINNER_PROGRAM, PROGRAM_VERSION
old=(ROOT/'supabase/migrations/202610230001_academy.sql').read_text()
transform=old[old.index('create or replace function academy_private.transform('):old.index('create or replace function academy_private.project_state(')]
transform=transform.replace("if act='diagnostic_start' then", """if act='route_select' then
  perform academy_private.require(not (s->>'program_approved')::boolean,'Утверждённую программу нельзя сменить без пересогласования');
  mode:=academy_private.str(p,'route',1,40);
  perform academy_private.require(mode in ('beginner','diagnostic'),'Неизвестный маршрут');
  perform academy_private.require(mode is distinct from s->>'learning_route','Маршрут уже выбран');
  s:=s||jsonb_build_object('learning_route',mode,'program_version',coalesce((s->>'program_version')::bigint,0)+1,
    'program_history',coalesce(s->'program_history','[]'::jsonb)||jsonb_build_array(jsonb_build_object('route',s->'learning_route','program',s->'program','at',stamp)),
    'curriculum_version',case when mode='beginner' then 'beginner-2026-10-v1' else 'diagnostic-draft' end);
  if mode='beginner' then s:=jsonb_set(s,'{program}',academy_private.beginner_program());end if;
 elsif act='diagnostic_start' then""")
transform=transform.replace("s:=jsonb_set(s,'{program}',slots);", """if s->>'learning_route'='beginner' then
   j:=0;h:=academy_private.beginner_program();r:='[]'::jsonb;
   for v in select value from jsonb_array_elements(slots) loop
    perform academy_private.require(v->>'topic'=h->j->>'topic','Порядок базовой программы фиксирован');
    r:=r||jsonb_build_array((h->j)||jsonb_build_object('note',v->>'note'));j:=j+1;
   end loop;slots:=r;
  end if;
  s:=s||jsonb_build_object('program',slots,'program_version',coalesce((s->>'program_version')::bigint,0)+1);""")
transform=transform.replace("not (s->>'program_approved')::boolean and academy_private.diagnostic_complete(s),'Нужна проверка девяти тем; программа не должна быть уже утверждена'", "not (s->>'program_approved')::boolean and (s->>'learning_route'='beginner' or academy_private.diagnostic_complete(s)),'Выберите маршрут новичка либо завершите добровольную диагностику; программа не должна быть уже утверждена'")
transform=transform.replace("perform academy_private.require(p->>'confirmation'='УТВЕРЖДАЮ'", """if s->>'learning_route' is not null then
   perform academy_private.require(jsonb_typeof(p->'program_version')='number' and p->'program_version'=s->'program_version','Версия программы изменилась; просмотрите её заново');
  end if;
  perform academy_private.require(p->>'confirmation'='УТВЕРЖДАЮ'""")
transform=transform.replace("'Сначала диагностика и утверждение программы'", "'Сначала явное утверждение выбранной программы'")
transform=transform.replace("perform academy_private.require(v is null,'Задание уже начато');", """if s->>'learning_route'='beginner' then
    j:=array_position(array['paths','files','read','search','permissions'],k);
    for id in select unnest((array['paths','files','read','search','permissions'])[1:coalesce(j-1,5)]) loop
     perform academy_private.require(s#>>array['lessons',id,'status']='completed','Сначала завершите предыдущие базовые задания с проверкой');
    end loop;
   end if;
   perform academy_private.require(v is null,'Задание уже начато');""")
transform=transform.replace("(s->>'diagnostic_started')::boolean and not (s->>'program_approved')::boolean", "(s->>'diagnostic_started')::boolean and (not (s->>'program_approved')::boolean or s->>'learning_route'='beginner')")
projection=old[old.index('create or replace function academy_private.project_state('):old.index('create or replace function public.academy_load(')]
projection=projection.replace('begin\n insert into public.academy_programs', 'begin\n insert into public.academy_programs')
projection=projection.replace(" for k,v in select * from jsonb_each(s->'lessons') loop", """ update public.academy_programs set learning_route=s->>'learning_route',
  program_version=coalesce((s->>'program_version')::bigint,0),curriculum_version=s->>'curriculum_version' where user_id=uid;
 for k,v in select * from jsonb_each(s->'lessons') loop""")
body="""-- Optional diagnosis. No updates to existing learner state, no resets or deletes.
-- The route is chosen only through authenticated, revision-checked academy_action.
begin;
alter table public.academy_programs add column if not exists learning_route text check(learning_route in ('beginner','diagnostic'));
alter table public.academy_programs add column if not exists program_version bigint not null default 0 check(program_version>=0);
alter table public.academy_programs add column if not exists curriculum_version text;
create or replace function academy_private.beginner_program() returns jsonb
language sql immutable set search_path='' as $catalog$ select '"""+json.dumps(BEGINNER_PROGRAM,ensure_ascii=False).replace("'","''")+"'::jsonb $catalog$;\n"+transform+projection+"""revoke all on all functions in schema academy_private from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
"""
(ROOT/'supabase/migrations/202610230003_beginner_route.sql').write_text(body)
print('Generated additive migration with canonical 30-day program; no learner reads')
