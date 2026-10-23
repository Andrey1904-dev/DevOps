"""Synthetic learner state only; no access to the real account or SQLite."""
from copy import deepcopy
import unittest
from academy import Store,summary
from curriculum import BEGINNER_PROGRAM
from content import public_catalog

class BeginnerTests(unittest.TestCase):
 def setUp(self):self.store=Store()
 def tearDown(self):self.store.db.close()
 def choose(self):self.store.mutate('route_select',{'route':'beginner'})
 def approve(self):self.store.mutate('program_approve',{'confirmation':'УТВЕРЖДАЮ','program_version':self.store.read()['program_version']})
 def test_beginner_without_exam(self):
  self.choose();s=self.store.read();self.assertEqual(s['program'],BEGINNER_PROGRAM)
  self.assertFalse(s['diagnostic_started']);self.assertEqual(s['diagnostic'],{})
  self.approve();self.store.mutate('lesson_start',{'lesson':'paths'})
  s=self.store.read();self.assertFalse(summary(s)['diagnostic_complete']);self.assertEqual(summary(s)['completed'],0)
  self.assertEqual(s['lessons']['paths']['status'],'in_progress')
 def test_wrong_confirmation_or_stale_plan(self):
  self.choose()
  for p in ({'confirmation':'УТВЕРЖДАЮ'},{'confirmation':'УТВЕРЖДАЮ','program_version':0},{'confirmation':'ДА','program_version':1}):
   with self.assertRaises(ValueError):self.store.mutate('program_approve',p)
  self.store.mutate('program_save',{'program':deepcopy(BEGINNER_PROGRAM)})
  with self.assertRaises(ValueError):self.store.mutate('program_approve',{'confirmation':'УТВЕРЖДАЮ','program_version':1})
  self.approve()
 def test_diagnostic_route_still_requires_evidence(self):
  self.store.mutate('route_select',{'route':'diagnostic'})
  with self.assertRaises(ValueError):self.approve()
 def test_route_switch_preserves_all_evidence(self):
  self.store.mutate('diagnostic_start',{'confirmed':True})
  self.store.mutate('diagnostic_answer',{'topic':'linux','answer':'SYNTHETIC observation'})
  self.store.mutate('note',{'text':'SYNTHETIC note'})
  before=self.store.read();self.choose();after=self.store.read()
  for k in ('diagnostic','notes','attempts','lessons'):self.assertEqual(before[k],after[k])
  self.assertEqual(after['program_history'][0]['program'],before['program'])
  self.store.mutate('route_select',{'route':'diagnostic'})
  self.assertEqual(self.store.read()['diagnostic'],before['diagnostic'])
 def test_approved_route_cannot_be_overwritten(self):
  self.choose();self.approve();before=self.store.read()
  with self.assertRaises(ValueError):self.store.mutate('route_select',{'route':'diagnostic'})
  self.assertEqual(before,self.store.read())
 def test_cannot_skip_basic_verification(self):
  self.choose();self.approve()
  for k in ('files','permissions','python'):
   with self.assertRaises(ValueError):self.store.mutate('lesson_start',{'lesson':k})
 def test_no_user_id_spoof(self):
  with self.assertRaises(ValueError):self.store.mutate('route_select',{'route':'beginner','user_id':'other'})
 def test_cannot_replace_beginner_topics_or_inject_fields(self):
  self.choose();program=deepcopy(BEGINNER_PROGRAM);program[0]['topic']='forged'
  with self.assertRaises(ValueError):self.store.mutate('program_save',{'program':program})
  program=deepcopy(BEGINNER_PROGRAM);program[0]['lesson_id']='forged'
  self.store.mutate('program_save',{'program':program});self.assertEqual(self.store.read()['program'][0]['lesson_id'],'paths')
 def test_legacy_state_preserved(self):
  import json
  old=self.store.read()
  for k in ('learning_route','program_version','program_history'):old.pop(k)
  old['program_approved']=True
  self.store.db.execute('UPDATE academy SET body=?',(json.dumps(old),));self.store.db.commit()
  self.assertEqual(self.store.read(),old);self.store.mutate('note',{'text':'SYNTHETIC legacy note'})
  self.assertTrue(self.store.read()['program_approved']);self.assertEqual(self.store.read()['program'],old['program'])
 def test_beginner_may_take_optional_diagnostic_later(self):
  self.choose();self.approve();before=self.store.read()['program']
  self.store.mutate('diagnostic_start',{'confirmed':True})
  self.store.mutate('diagnostic_answer',{'topic':'linux','answer':'SYNTHETIC optional later observation'})
  self.assertEqual(self.store.read()['program'],before)
  self.assertEqual(summary(self.store.read())['completed'],0)
 def test_sql_catalog_matches_python_exactly(self):
  import json
  from pathlib import Path
  sql=(Path(__file__).resolve().parents[1]/'supabase/migrations/202610230003_beginner_route.sql').read_text()
  raw=sql.split("as $catalog$ select '",1)[1].split("'::jsonb $catalog$",1)[0].replace("''", "'")
  self.assertEqual(json.loads(raw),BEGINNER_PROGRAM)
 def test_program_and_content_readiness_contract(self):
  c=public_catalog();self.assertEqual(len(c['beginner_program']),30)
  self.assertEqual([d['readiness'] for d in c['beginner_program']].count('ready'),5)
  for d in c['beginner_program']:
   for f in ('topic','goal','hours','theory','practice','completion','repeat'):self.assertTrue(d[f])
  for l in c['lessons'][:5]:
   for f in ('why','analogy','foundation','examples','task','hints','criteria','mistakes','outcome','mini_challenge'):self.assertTrue(l[f])
   self.assertNotEqual(l['task'],l['examples'][0])
