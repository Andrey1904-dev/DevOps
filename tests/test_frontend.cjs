/* Rendering checks in a DOM stub; these are not browser or visual tests. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const {spawnSync} = require('node:child_process');
const fixture = spawnSync('python3',['-B','-c',
 'import json; from content import public_catalog; from academy import initial_state,summary; s=initial_state(); print(json.dumps(dict(catalog=public_catalog(),state=s,summary=summary(s))))'],{encoding:'utf8'});
assert.equal(fixture.status,0,fixture.stderr);
const data=JSON.parse(fixture.stdout);
const elements={'#app':{innerHTML:''},'#notice':{innerHTML:''}};
const ctx={console,URLSearchParams,Date,setTimeout,clearTimeout,location:{hash:'#home'},
 document:{querySelector:q=>elements[q],querySelectorAll:()=>[],addEventListener:()=>{}},
 window:{addEventListener:()=>{},scrollTo:()=>{}},
 fetch:async path=>({ok:true,json:async()=>path==='/api/catalog'?data.catalog:{state:data.state,summary:data.summary,csrf:'synthetic-test-only'}})};
vm.createContext(ctx);
vm.runInContext(fs.readFileSync('web/app.js','utf8'),ctx);
setImmediate(()=>{
 let checks=0;
 function run(code){return vm.runInContext(code,ctx);}
 function page(hash,contains){ctx.location.hash=hash;run('render()');assert.ok(elements['#app'].innerHTML.includes(contains),hash);checks++;return elements['#app'].innerHTML;}
 for(const [route,title] of Object.entries({home:'Понимать.',diagnostic:'Начать только по вашему решению',program:'30 дней',lessons:'Учебные материалы',labs:'Лаборатории без риска',mentors:'Специализация под конкретную задачу',progress:'Прогресс опирается на попытки',settings:'Понятное хранение'}))page('#'+route,title);
 for(const lesson of data.catalog.lessons)page('#lesson/'+lesson.id,'Самостоятельная практика');
 assert.equal((page('#program','Сохранить заметки к плану').match(/aria-label="Тема дня/g)||[]).length,30);checks++;
 run(`state.learning_route='beginner';state.program=catalog.beginner_program;state.program_version=1`);
 const beginner=page('#program','диагностика не требуется'.replace('диагностика','Диагностика'));
 assert.ok(!beginner.includes('name="confirmation" required autocomplete="off" disabled'));checks++;
 assert.ok(beginner.includes('Полный стартовый урок'));checks++;
 assert.ok(beginner.includes('полный урок ещё не готов'));checks++;
 page('#home','Я новичок, начать с нуля');page('#diagnostic','Проверить мои знания');
 for(const key of ['paths','files','read','search','permissions']){const html=page('#lesson/'+key,'Мини-челлендж');assert.ok(html.includes('Техническая основа'));checks++;}
 assert.equal(run(`esc('<img src=x onerror=bad()>')`),'&lt;img src=x onerror=bad()&gt;');checks++;
 run('state.diagnostic_started=true');page('#diagnostic/python','Проследите на бумаге');
 run(`state.diagnostic.python=[{id:'synthetic',at:'2026-10-23T00:00:00Z',answer:'<script>bad()</script>',review:{rating:'support',feedback:'synthetic'}}]`);
 const diag=page('#diagnostic/python','Уточняющий шаг');assert.ok(diag.includes('&lt;script&gt;bad()&lt;/script&gt;'));checks++;
 run(`state.program_approved=true;state.lessons.paths={status:'in_progress',hint_level:1};state.attempts=[{id:'synthetic',lesson:'paths',answer:'synthetic',explanation:'synthetic explanation',mode:'hint',hint_level:1,check:'manual',at:'2026-10-23T00:00:00Z',review:null}]`);
 page('#lesson/paths','Сохранить внешнюю проверку');page('#progress','С подсказкой');
 assert.equal(data.state.events.length,0);checks++;
 console.log(JSON.stringify({render_checks:checks,result:'passed',visual_check:false}));
});
