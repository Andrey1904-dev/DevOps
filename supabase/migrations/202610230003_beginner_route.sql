-- Optional diagnosis. No updates to existing learner state, no resets or deletes.
-- The route is chosen only through authenticated, revision-checked academy_action.
begin;
alter table public.academy_programs add column if not exists learning_route text check(learning_route in ('beginner','diagnostic'));
alter table public.academy_programs add column if not exists program_version bigint not null default 0 check(program_version>=0);
alter table public.academy_programs add column if not exists curriculum_version text;
create or replace function academy_private.beginner_program() returns jsonb
language sql immutable set search_path='' as $catalog$ select '[{"day": 1, "topic": "Терминал: где я?", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Различить команду, вывод и два вида пути", "theory": "Терминал, оболочка, корень /, текущий каталог, . и ..", "practice": "Разобрать маршрут к заметке в бумажной модели RP-сервера", "completion": "Верный абсолютный путь и объяснение зависимости от исходной папки", "repeat": "Повторить корень и родительский каталог; новый пример без копирования", "lesson_id": "paths", "readiness": "ready"}, {"day": 2, "topic": "Файлы: переезд без потерь", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Различить файл, каталог, копирование и перемещение", "theory": "Дерево имён; mkdir, cp, mv только как читаемые примеры", "practice": "Показать копию заметки в архиве и сохранить исходник", "completion": "Два пути к файлам и объяснение, чем копия отличается от перемещения", "repeat": "Нарисовать дерево до и после операции", "lesson_id": "files", "readiness": "ready"}, {"day": 3, "topic": "Логи: читать, а не колдовать", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Найти событие и отделить наблюдение от причины", "theory": "cat, head, tail; уровни INFO, WARN, ERROR; текст не исполняется", "practice": "Разобрать синтетический журнал запуска игрового сервиса", "completion": "Время и сообщение ошибки; причина помечена как гипотеза", "repeat": "Разделить буквальную запись и предположение", "lesson_id": "read", "readiness": "ready"}, {"day": 4, "topic": "Поиск: поймать нужную строку", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Отличить совпадение поля от подстроки", "theory": "grep, якорь ^, поле уровня; find ищет пути, grep — текст", "practice": "Отобрать только события с уровнем ERROR", "completion": "Точный набор строк и критерий отбора", "repeat": "Проверить ложное совпадение WARN error_count", "lesson_id": "search", "readiness": "ready"}, {"day": 5, "topic": "Права: ключи от базы", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Прочитать права обычного файла по ролям", "theory": "Владелец, группа, остальные; r/w/x; у каталогов иной смысл", "practice": "Разобрать доступ к бумажному файлу технологической базы", "completion": "Отдельно обоснованы чтение и запись; никакого изменения прав на Mac", "repeat": "Выбрать класс пользователя до чтения его битов", "lesson_id": "permissions", "readiness": "ready"}, {"day": 6, "topic": "Процессы: жив, но не здоров", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Отличить наличие процесса от исправности сервиса", "theory": "PID, состояние, CPU и память; ps как наблюдение", "practice": "Разделить факты и гипотезы в снимке нагрузки RP-сервера", "completion": "Два наблюдения и одна проверяемая гипотеза без перезапуска", "repeat": "Вернуться к разбору журнала дня 3", "lesson_id": "processes", "readiness": "outline"}, {"day": 7, "topic": "Службы: кто будит сервер", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Объяснить запуск и жизненный цикл фоновой службы", "theory": "Процесс и служба; systemd Linux против launchd macOS", "practice": "Нарисовать запуск условного сервиса и место его журнала", "completion": "Среда названа; start/restart не предлагаются на основной машине", "repeat": "Повторить PID и отделение среды от команды", "lesson_id": null, "readiness": "outline"}, {"day": 8, "topic": "Сети: адрес, дверь и имя", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Развести IP, порт, DNS, HTTP и SSH", "theory": "Адрес узла, порт приложения, DNS-запись, код HTTP, проверка SSH-хоста", "practice": "Разобрать синтетический инцидент подключения к игровому миру", "completion": "Не путать успешный DNS с исправностью HTTP; запросить новое наблюдение", "repeat": "Повторить факт/гипотезу и схему клиент → сервис", "lesson_id": "network", "readiness": "outline"}, {"day": 9, "topic": "Git: машина времени команды", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Развести рабочее дерево, индекс и коммит", "theory": "git status, diff, add, commit на бумажной истории", "practice": "Определить версию конфигурации в следующем коммите", "completion": "Выбор обоснован содержимым индекса", "repeat": "Нарисовать три состояния одного файла", "lesson_id": "git", "readiness": "outline"}, {"day": 10, "topic": "Git: две линии обновления", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Объяснить ветку и конфликт", "theory": "Ветка — ссылка на коммит; merge объединяет историю", "practice": "Сопоставить две правки синтетической конфигурации", "completion": "Обе правки рассмотрены, нет удаления чужой истории", "repeat": "Повторить снимки и diff дня 9", "lesson_id": null, "readiness": "outline"}, {"day": 11, "topic": "GitHub: обзор перед релизом", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Подготовить понятный PR без секретов", "theory": "Remote, push, PR, review, защита ветки", "practice": "Написать описание вымышленного изменения и план проверки", "completion": "Проблема, изменение, тесты и риски названы; история сохранена", "repeat": "Повторить ветки и понятие доверенной проверки", "lesson_id": null, "readiness": "outline"}, {"day": 12, "topic": "Bash: аргумент не рассыпался", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Объяснить переменные и кавычки", "theory": "Аргументы, пробелы, двойные кавычки; Bash 3.2 против новых версий", "practice": "Разобрать бумажный путь с пробелом и проверить цель", "completion": "Аргументы и безопасность пути объяснены отдельно", "repeat": "Повторить относительные пути дня 1", "lesson_id": "bash", "readiness": "outline"}, {"day": 13, "topic": "Bash: диагностика без сюрпризов", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Спроектировать предсказуемый сбор наблюдений", "theory": "Код возврата, ветвление, валидация входа; ограничения set -e", "practice": "Составить псевдокод отчёта о вымышленном сервисе", "completion": "Ошибки видимы; нет удаления, скрытых изменений и реального запуска", "repeat": "Повторить аргументы и наблюдения дня 6", "lesson_id": null, "readiness": "outline"}, {"day": 14, "topic": "Python: перезагрузка памяти", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Восстановить переменные, условия и for", "theory": "Строки, числа, bool, список; порядок итераций", "practice": "Проследить фильтр синтетических событий по шагам", "completion": "Для каждой итерации показаны условие и состояние", "repeat": "Разобрать два элемента вместо всего списка", "lesson_id": null, "readiness": "outline"}, {"day": 15, "topic": "Python: детектив логов", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Спроектировать простой счётчик событий", "theory": "split, словарь счётчиков, обработка пустой строки", "practice": "На бумаге посчитать причины отключений в искусственном журнале", "completion": "Результат связан с исходными строками; плохая строка обработана", "repeat": "Повторить цикл и условие дня 14", "lesson_id": "python", "readiness": "outline"}, {"day": 16, "topic": "Контейнер: коробка с правилами", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Отличить контейнер от виртуальной машины", "theory": "Образ, контейнер, общее ядро; Linux VM в Docker Desktop на Mac", "practice": "Нарисовать границы учебного сервиса; ничего не устанавливать", "completion": "Контейнер не назван отдельным ядром или гарантированной песочницей", "repeat": "Повторить процесс и среду дня 6", "lesson_id": null, "readiness": "outline"}, {"day": 17, "topic": "Dockerfile: рецепт сборки", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Прочитать рецепт без выполнения", "theory": "FROM, WORKDIR, COPY, RUN, CMD; фиксированные зависимости", "practice": "Проверить вымышленный рецепт безопасного приложения", "completion": "Отличены build и runtime; секретов и root по умолчанию избегают", "repeat": "Повторить образ и контейнер дня 16", "lesson_id": null, "readiness": "outline"}, {"day": 18, "topic": "Контейнерная сеть и данные", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Развести порт сервиса и постоянные данные", "theory": "Публикация портов, bind/volume, жизненный цикл контейнера", "practice": "Спроектировать хранение синтетических логов без подключения диска Mac", "completion": "Данные и доступы минимальны, привязки к реальному хосту отсутствуют", "repeat": "Повторить IP/порт и границы среды", "lesson_id": null, "readiness": "outline"}, {"day": 19, "topic": "Compose: сервисы договорились", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Прочитать связи нескольких сервисов", "theory": "Сервисы, сеть, healthcheck, зависимости; ready не равно started", "practice": "Нарисовать приложение и учебную БД; подготовить план изоляции", "completion": "Названы проверки готовности и границы; запуск требует отдельной среды", "repeat": "Повторить состояние процесса и хранение", "lesson_id": null, "readiness": "outline"}, {"day": 20, "topic": "CI/CD: релиз без гадания", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Разделить сборку, проверку и публикацию", "theory": "Pipeline, artifact, CI и CD; доверенные границы", "practice": "Нарисовать путь игрового обновления от PR до артефакта", "completion": "Публикация невозможна при проваленных проверках", "repeat": "Повторить PR и критерии проверок", "lesson_id": null, "readiness": "outline"}, {"day": 21, "topic": "Actions: читаем workflow", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Объяснить триггер, job и step", "theory": "on, jobs, needs, permissions; SHA действий", "practice": "Разобрать учебный YAML без его запуска", "completion": "Названы входы, права и условия выполнения", "repeat": "Повторить CI и ветки", "lesson_id": null, "readiness": "outline"}, {"day": 22, "topic": "Тесты до аплодисментов", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Развести проверку поведения и красивый зелёный значок", "theory": "Позитивные, негативные сценарии, артефакты и логи", "practice": "Составить тесты счётчика синтетических логов", "completion": "Есть неверный вход и объяснимый отказ; нет ложного успеха", "repeat": "Повторить критерии и обработку ошибок Python", "lesson_id": null, "readiness": "outline"}, {"day": 23, "topic": "Безопасный учебный релиз", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Описать контролируемую публикацию и откат", "theory": "Environment, минимальный token, ручное одобрение; без реального деплоя", "practice": "Составить план выпуска вымышленного сервиса и восстановления", "completion": "Есть проверка версии, прав и возврата; секретов в YAML нет", "repeat": "Повторить доверенные границы и PR", "lesson_id": null, "readiness": "outline"}, {"day": 24, "topic": "Логи: собрать историю сбоя", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Связать события без выдумывания причины", "theory": "Время, уровень, correlation ID, персональные данные", "practice": "Восстановить хронологию синтетического инцидента после обновления", "completion": "Факты отделены от причин, чувствительные поля исключены", "repeat": "Повторить чтение и поиск дней 3–4", "lesson_id": null, "readiness": "outline"}, {"day": 25, "topic": "Метрики: где тормозит мир", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Выбрать полезные показатели и симптом", "theory": "Latency, traffic, errors, saturation; порог не равен причине", "practice": "Сравнить два снимка нагрузки вымышленной игровой площадки", "completion": "Гипотеза опирается на несколько наблюдений, есть следующее измерение", "repeat": "Повторить процессы и HTTP", "lesson_id": null, "readiness": "outline"}, {"day": 26, "topic": "DevSecOps: доступ по необходимости", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Распознать секрет и ограничить права", "theory": "Least privilege, зависимости, secret scanning; только вымышленные ключи", "practice": "Разобрать утечку FAKE_EXAMPLE_NOT_A_KEY и права базы супергероев", "completion": "Есть план отзыва/замены, удаление коммита не объявлено отзывом", "repeat": "Повторить права дня 5 и границы CI", "lesson_id": null, "readiness": "outline"}, {"day": 27, "topic": "Проект: карта системы", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Ограничить объём интеграционного проекта", "theory": "Контракт, входные данные, компоненты и угрозы", "practice": "Спроектировать анализатор логов условного игрового сервиса", "completion": "Малый MVP и проверяемые критерии; среда отдельно согласована", "repeat": "Повторить самые слабые темы по реальным попыткам", "lesson_id": null, "readiness": "outline"}, {"day": 28, "topic": "Проект: проверяемое изменение", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Связать код, историю и тесты", "theory": "Небольшие изменения, фикстуры, обработка ошибок", "practice": "Подготовить артефакты проекта в согласованной учебной среде", "completion": "Есть собственная попытка, тесты и объяснение; AI не выполняет за ученика", "repeat": "Сократить задачу до одного входа и одного результата", "lesson_id": null, "readiness": "outline"}, {"day": 29, "topic": "Проект: эксплуатационный взгляд", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Подготовить наблюдение и восстановление", "theory": "README запуска, синтетические логи, ограничения и план отката", "practice": "Проверить проект на новом наборе данных и описать сбой", "completion": "Есть воспроизводимость, негативный сценарий и признанные ограничения", "repeat": "Вернуться к проваленной проверке, а не скрывать её", "lesson_id": null, "readiness": "outline"}, {"day": 30, "topic": "Демонстрация без магии", "hours": "2–4", "note": "Темп меняется по результатам; это ориентир, не дедлайн.", "goal": "Объяснить собственное решение и план дальнейшего роста", "theory": "Повторение слабых тем и перенос навыка; собеседование без обещаний", "practice": "Показать проект, ответить на уточнения и решить одну новую малую задачу", "completion": "Объяснены решения, помощь отмечена; пробелы превращены в план повторения", "repeat": "Вернуться к конкретным неподтверждённым навыкам", "lesson_id": null, "readiness": "outline"}]'::jsonb $catalog$;
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
 if act='route_select' then
  perform academy_private.require(not (s->>'program_approved')::boolean,'Утверждённую программу нельзя сменить без пересогласования');
  mode:=academy_private.str(p,'route',1,40);
  perform academy_private.require(mode in ('beginner','diagnostic'),'Неизвестный маршрут');
  perform academy_private.require(mode is distinct from s->>'learning_route','Маршрут уже выбран');
  s:=s||jsonb_build_object('learning_route',mode,'program_version',coalesce((s->>'program_version')::bigint,0)+1,
    'program_history',coalesce(s->'program_history','[]'::jsonb)||jsonb_build_array(jsonb_build_object('route',s->'learning_route','program',s->'program','at',stamp)),
    'curriculum_version',case when mode='beginner' then 'beginner-2026-10-v1' else 'diagnostic-draft' end);
  if mode='beginner' then s:=jsonb_set(s,'{program}',academy_private.beginner_program());end if;
 elsif act='diagnostic_start' then
  perform academy_private.require(p->'confirmed'='true'::jsonb,'Нужно явное решение начать');
  perform academy_private.require(not (s->>'diagnostic_started')::boolean,'Диагностика уже начата');
  s:=jsonb_set(s,'{diagnostic_started}','true');
 elsif act in ('diagnostic_answer','diagnostic_review') then
  perform academy_private.require((s->>'diagnostic_started')::boolean and (not (s->>'program_approved')::boolean or s->>'learning_route'='beginner'),'Диагностика не открыта или её снимок уже закрыт');
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
  if s->>'learning_route'='beginner' then
   j:=0;h:=academy_private.beginner_program();r:='[]'::jsonb;
   for v in select value from jsonb_array_elements(slots) loop
    perform academy_private.require(v->>'topic'=h->j->>'topic','Порядок базовой программы фиксирован');
    r:=r||jsonb_build_array((h->j)||jsonb_build_object('note',v->>'note'));j:=j+1;
   end loop;slots:=r;
  end if;
  s:=s||jsonb_build_object('program',slots,'program_version',coalesce((s->>'program_version')::bigint,0)+1);
 elsif act='program_approve' then
  perform academy_private.require(not (s->>'program_approved')::boolean and (s->>'learning_route'='beginner' or academy_private.diagnostic_complete(s)),'Выберите маршрут новичка либо завершите добровольную диагностику; программа не должна быть уже утверждена');
  if s->>'learning_route' is not null then
   perform academy_private.require(jsonb_typeof(p->'program_version')='number' and p->'program_version'=s->'program_version','Версия программы изменилась; просмотрите её заново');
  end if;
  perform academy_private.require(p->>'confirmation'='УТВЕРЖДАЮ','Нужно явное утверждение');
  s:=s||jsonb_build_object('program_approved',true,'program_approved_at',stamp);
 elsif act in ('lesson_start','hint','attempt') then
  k:=academy_private.str(p,'lesson',1,40);
  perform academy_private.require(k=any(array['paths','files','read','search','permissions','processes','bash','git','network','python']),'Неизвестное задание');
  perform academy_private.require((s->>'program_approved')::boolean,'Сначала явное утверждение выбранной программы');
  v:=s#>array['lessons',k];
  if act='lesson_start' then
   if s->>'learning_route'='beginner' then
    j:=array_position(array['paths','files','read','search','permissions'],k);
    for id in select unnest((array['paths','files','read','search','permissions'])[1:coalesce(j-1,5)]) loop
     perform academy_private.require(s#>>array['lessons',id,'status']='completed','Сначала завершите предыдущие базовые задания с проверкой');
    end loop;
   end if;
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
 update public.academy_programs set learning_route=s->>'learning_route',
  program_version=coalesce((s->>'program_version')::bigint,0),curriculum_version=s->>'curriculum_version' where user_id=uid;
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

revoke all on all functions in schema academy_private from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
