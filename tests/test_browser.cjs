/* Real Chromium, synthetic in-memory local server only. Never uses an owner session. */
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const root=path.resolve(__dirname,'..'),audit=path.join(root,'audit');
fs.mkdirSync(path.join(audit,'browser-tmp'),{recursive:true});
process.env.TMPDIR=path.join(audit,'browser-tmp');
const {chromium}=require(process.env.ACADEMY_PLAYWRIGHT||'playwright');
async function fixture(){const p=spawn('python3',['-B','tests/preview_fixture.py'],{cwd:root,stdio:['pipe','pipe','pipe']});p.stderr.on('data',d=>process.stderr.write(d));const port=await new Promise((res,rej)=>{p.stdout.once('data',d=>res(Number(String(d).trim())));p.once('error',rej);});return {p,url:'http://127.0.0.1:'+port};}
(async()=>{
 const f=await fixture();let browser;let checks=0;const errors=[];
 try{
  browser=await chromium.launch({headless:true,channel:'chrome',chromiumSandbox:true,downloadsPath:audit});
  const page=await browser.newPage({viewport:{width:1440,height:1000}});page.on('pageerror',e=>errors.push(e.message));
  await page.goto(f.url);await page.getByRole('button',{name:'Я новичок, начать с нуля',exact:true}).click();
  await page.getByRole('heading',{name:'30 дней — рабочий черновик',exact:true}).waitFor();checks++;
  assert.equal(await page.locator('[aria-label^="Тема дня"]').count(),30);checks++;
  await page.getByText('Полный стартовый урок',{exact:true}).first().click();
  await page.screenshot({path:path.join(audit,'beginner-desktop.png'),fullPage:false});
  await page.getByLabel('Введите УТВЕРЖДАЮ',{exact:true}).fill('УТВЕРЖДАЮ');
  await page.getByRole('button',{name:'Утвердить сохранённую программу',exact:true}).click();
  await page.getByRole('heading',{name:'Терминал: GPS для инженера',exact:true}).waitFor();checks++;
  await page.getByRole('button',{name:'Начать задание',exact:true}).click();
  await page.getByRole('heading',{name:'Ваша попытка',exact:true}).waitFor();checks++;
  await page.reload();await page.getByRole('heading',{name:'Ваша попытка',exact:true}).waitFor();checks++;
  const state=await page.evaluate(async()=>{const r=await fetch('/api/state');return r.json();});
  assert.equal(state.state.learning_route,'beginner');assert.equal(state.state.diagnostic_started,false);
  assert.deepEqual(state.state.diagnostic,{});assert.equal(state.state.attempts.length,0);assert.equal(state.summary.completed,0);checks+=5;
  await page.setViewportSize({width:390,height:844});await page.screenshot({path:path.join(audit,'beginner-mobile.png'),fullPage:false});
  const metrics=await page.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth}));assert.equal(metrics.width,metrics.scroll);checks++;
  await page.getByRole('link',{name:'Прогресс',exact:true}).click();await page.getByRole('heading',{name:'Прогресс по дням',exact:true}).waitFor();checks++;
  await page.getByRole('link',{name:'Обзор',exact:true}).click();await page.getByRole('heading',{name:'Понимать. Делать. Объяснять.',exact:true}).waitFor();
  await page.getByRole('button',{name:'Начать первый урок →',exact:true}).click();await page.getByRole('heading',{name:'Ваша попытка',exact:true}).waitFor();checks++;
  assert.deepEqual(errors,[]);checks++;
  // A second independent in-memory learner chooses voluntary diagnosis.
  const d=await fixture();try{
   const p=await browser.newPage({viewport:{width:390,height:844}});await p.goto(d.url);
   await p.getByRole('button',{name:'Проверить мои знания',exact:true}).click();await p.getByRole('button',{name:'Я решил начать диагностику',exact:true}).waitFor();checks++;
   await p.getByRole('button',{name:'Я решил начать диагностику',exact:true}).click();await p.getByLabel('Ваш ответ и ход мысли',{exact:true}).waitFor();
   await p.getByLabel('Ваш ответ и ход мысли',{exact:true}).fill('SYNTHETIC ONLY: not learner evidence');await p.getByRole('button',{name:'Сохранить свою попытку',exact:true}).click();
   await p.getByText('SYNTHETIC ONLY: not learner evidence',{exact:true}).waitFor();checks++;
   await p.getByRole('button',{name:'Я новичок, начать с нуля',exact:true}).click();await p.getByRole('heading',{name:'30 дней — рабочий черновик',exact:true}).waitFor();
   await p.reload();await p.getByRole('heading',{name:'30 дней — рабочий черновик',exact:true}).waitFor();
   const s=await p.evaluate(async()=>{const r=await fetch('/api/state');return r.json();});assert.equal(s.state.diagnostic.terminal.length,1);checks++;
   await p.route('**/api/action/**',r=>r.abort('failed'));
   await p.getByRole('button',{name:'Сохранить заметки к плану',exact:true}).click();await p.locator('#notice .error').waitFor();checks++;
   const kept=await p.evaluate(async()=>{const r=await fetch('/api/state');return r.json();});assert.equal(kept.state.program_version,s.state.program_version);checks++;
   await p.close();
  }finally{d.p.stdin.end();}
  const report={checks,result:'passed',browser:'Google Chrome via Playwright',desktop:[1440,1000],mobile:[390,844],horizontalOverflow:false,consoleErrors:errors,realOwnerActions:0,scope:'Synthetic loopback fixture, not production Auth or real JWT'};
  fs.writeFileSync(path.join(audit,'browser-task6.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
 }finally{if(browser)await browser.close();f.p.stdin.end();}
})().catch(e=>{console.error(e);process.exitCode=1;});
