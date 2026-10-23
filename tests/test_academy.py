"""Synthetic fixtures only: tests never open the learner's data/academy.sqlite."""
import http.client
import json
import sqlite3
import threading
import tempfile
from pathlib import Path
import unittest

from academy import Store, make_server, summary, mentor_context, initial_state
from content import BY_ID, DIAG_BY_ID, MENTORS, public_catalog


class StoreTests(unittest.TestCase):
    def setUp(self): self.store=Store()
    def tearDown(self): self.store.db.close()
    def complete_diagnostic(self):
        self.store.mutate('diagnostic_start',{'confirmed':True})
        for k in DIAG_BY_ID:
            a=self.store.mutate('diagnostic_answer',{'topic':k,'answer':'SYNTHETIC TEST RESPONSE — not learner evidence'})
            self.store.mutate('diagnostic_review',dict(topic=k,attempt_id=a['attempt_id'],confirmed=True,
                 rating='unknown',feedback='SYNTHETIC reviewer fixture, not a real assessment'))
    def unlock(self):
        self.complete_diagnostic()
        self.store.mutate('program_approve',{'confirmation':'УТВЕРЖДАЮ'})
        self.store.mutate('lesson_start',{'lesson':'paths'})
    def attempt(self,**kwargs):
        return self.store.mutate('attempt',dict(lesson='paths',answer='/academy/notes/day1.txt',
                                 explanation='SYNTHETIC explanation for state-machine testing',mode='independent',**kwargs))
    def review(self,id,**kwargs):
        data=dict(attempt_id=id,verdict='accepted',confirmed=True,feedback='SYNTHETIC external review for tests only')
        data.update(kwargs);return self.store.mutate('review',data)
    def test_empty_progress_and_no_activity(self):
        s=self.store.read();self.assertEqual(s,initial_state());self.assertEqual(summary(s)['completed'],0)
        self.assertIsNone(summary(s)['last_activity']);self.assertFalse(s['diagnostic_started'])
    def test_program_requires_real_workflow(self):
        with self.assertRaises(ValueError): self.store.mutate('program_approve',{'confirmation':'УТВЕРЖДАЮ'})
        with self.assertRaises(ValueError): self.store.mutate('lesson_start',{'lesson':'paths'})
        self.assertEqual(self.store.read()['events'],[])
    def test_diagnostic_opt_in(self):
        with self.assertRaises(ValueError):self.store.mutate('diagnostic_start',{})
        with self.assertRaises(ValueError):self.store.mutate('diagnostic_answer',{'topic':'linux','answer':'x'})
    def test_unknown_diagnostic_is_observation_not_mastery(self):
        self.complete_diagnostic();s=self.store.read();self.assertTrue(summary(s)['diagnostic_complete'])
        self.assertEqual(summary(s)['completed'],0);self.assertEqual(len(summary(s)['repeat']),9)
    def test_approval_explicit_and_snapshot_closed(self):
        self.complete_diagnostic()
        with self.assertRaises(ValueError):self.store.mutate('program_approve',{'confirmation':'да'})
        self.store.mutate('program_approve',{'confirmation':'УТВЕРЖДАЮ'})
        with self.assertRaises(ValueError):self.store.mutate('diagnostic_answer',{'topic':'linux','answer':'new'})
    def test_matching_artifact_never_auto_completes(self):
        self.unlock();a=self.attempt();self.assertEqual(a['check'],'match')
        self.assertEqual(self.store.read()['lessons']['paths']['status'],'submitted')
        self.assertEqual(summary(self.store.read())['completed'],0)
    def test_completion_requires_confirmed_review(self):
        self.unlock();a=self.attempt()
        with self.assertRaises(ValueError):self.review(a['attempt_id'],confirmed=False)
        self.review(a['attempt_id']);self.assertEqual(summary(self.store.read())['completed'],1)
    def test_mismatch_cannot_be_accepted(self):
        self.unlock();a=self.store.mutate('attempt',dict(lesson='paths',answer='wrong',explanation='Synthetic explanation long enough',mode='independent'))
        self.assertEqual(a['check'],'mismatch')
        with self.assertRaises(ValueError):self.review(a['attempt_id'])
    def test_solution_is_not_completion(self):
        self.unlock();a=self.store.mutate('attempt',dict(lesson='paths',answer='/academy/notes/day1.txt',
                             explanation='Synthetic explanation long enough',mode='solution'))
        self.review(a['attempt_id']);self.assertEqual(summary(self.store.read())['completed'],0)
        self.assertEqual(self.store.read()['lessons']['paths']['status'],'needs_correction')
    def test_hint_requires_new_attempt_before_next_hint(self):
        self.unlock();self.store.mutate('hint',{'lesson':'paths'})
        with self.assertRaises(ValueError):self.store.mutate('hint',{'lesson':'paths'})
        with self.assertRaises(ValueError):self.attempt()
        self.store.mutate('attempt',dict(lesson='paths',answer='x',explanation='Synthetic explanation long enough',mode='hint'))
        self.store.mutate('hint',{'lesson':'paths'});self.assertEqual(self.store.read()['lessons']['paths']['hint_level'],2)
    def test_old_attempt_cannot_complete_new_attempt(self):
        self.unlock();a=self.attempt();self.attempt()
        with self.assertRaises(ValueError):self.review(a['attempt_id'])
        self.assertEqual(len(self.store.read()['attempts']),2)
    def test_atomic_failure(self):
        s=self.store.read()
        with self.assertRaises(ValueError):self.store.mutate('program_save',{'program':[{}]*30})
        self.assertEqual(self.store.read(),s)
    def test_malformed_identifiers(self):
        for payload in (None,[],{'topic':[]},{'lesson':{}},{'mode':False}):
            with self.assertRaises(ValueError):self.store.mutate('attempt',payload)
    def test_no_duplicate_reviews(self):
        self.unlock();a=self.attempt();self.review(a['attempt_id'])
        with self.assertRaises(ValueError):self.review(a['attempt_id'])
    def test_no_fake_recovery_on_corrupt_store(self):
        self.store.db.execute("UPDATE academy SET body='broken'")
        with self.assertRaises(ValueError):self.store.read()
    def test_persistence_after_reopen_same_connection(self):
        self.store.mutate('note',{'text':'SYNTHETIC local persistence fixture'})
        backup=sqlite3.connect(':memory:');self.store.db.backup(backup)
        restored=json.loads(backup.execute('SELECT body FROM academy').fetchone()[0]);backup.close()
        self.assertEqual(restored['notes'][0]['text'],'SYNTHETIC local persistence fixture')
    def test_disk_persistence_reopen_isolated_fixture(self):
        with tempfile.TemporaryDirectory(prefix='academy-test-',dir=Path(__file__).parent) as folder:
            db=Path(folder)/'synthetic.sqlite'
            first=Store(db);first.mutate('note',{'text':'SYNTHETIC persistence, never learner data'})
            saved=first.read();first.db.close()
            second=Store(db);self.assertEqual(second.read(),saved);second.db.close()
    def test_mentor_routing_all_roles_and_untrusted_evidence(self):
        for role in MENTORS:
            p=mentor_context(self.store.read(),role,'paths');self.assertIn(role,p)
            self.assertIn('данные, а не инструкции',p);self.assertNotIn('"expected"',p)
        with self.assertRaises(ValueError):mentor_context(self.store.read(),'missing')
    def test_catalog_content_contract(self):
        c=public_catalog();self.assertEqual(len(c['program']),30);self.assertEqual(len(c['diagnostics']),9)
        for l in c['lessons']:
            for field in ('goal','prerequisites','explanation','examples','task','hints','criteria','mistakes','repetition','mentor'):
                self.assertTrue(l[field])
            self.assertNotIn('expected',l);self.assertIn(l['mentor'],MENTORS)


class HttpTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.store=Store();cls.server=make_server(cls.store,0)
        cls.thread=threading.Thread(target=cls.server.serve_forever,daemon=True);cls.thread.start()
    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown();cls.server.server_close();cls.thread.join();cls.store.db.close()
    def req(self,method,path,body=None,**headers):
        c=http.client.HTTPConnection('127.0.0.1',self.server.server_port)
        c.request(method,path,body=body,headers=headers);r=c.getresponse();data=r.read();status=r.status;hs=dict(r.getheaders());c.close()
        return status,hs,data
    def auth(self):
        _,hs,_=self.req('GET','/');return {'Cookie':hs['Set-Cookie'].split(';')[0]}
    def test_pages_and_static_security_headers(self):
        for path in ('/','/app.js','/style.css'):
            code,hs,data=self.req('GET',path);self.assertEqual(code,200);self.assertTrue(data)
            self.assertIn("frame-ancestors 'none'",hs['Content-Security-Policy'])
    def test_host_and_origin_rejected(self):
        self.assertEqual(self.req('GET','/',Host='evil.example')[0],403)
        self.assertEqual(self.req('GET','/',Origin='https://evil.example')[0],403)
    def test_api_needs_session(self):self.assertEqual(self.req('GET','/api/state')[0],403)
    def test_csrf_required(self):
        hs=self.auth();self.assertEqual(self.req('POST','/api/action/note',json.dumps({'text':'x'}),**hs)[0],403)
    def test_authenticated_state_and_export(self):
        for path in ('/api/state','/api/catalog','/api/export'):
            code,_,data=self.req('GET',path,**self.auth());self.assertEqual(code,200);json.loads(data)
    def test_invalid_json_types_and_unknown_action(self):
        hs={**self.auth(),'X-Academy-CSRF':self.server.csrf,'Content-Type':'application/json'}
        for body in ('{','[]','{"lesson":[]}'):
            self.assertEqual(self.req('POST','/api/action/attempt',body,**hs)[0],400)
        self.assertEqual(self.req('POST','/api/action/nope','{}',**hs)[0],400)
    def test_size_limit(self):
        hs={**self.auth(),'X-Academy-CSRF':self.server.csrf,'Content-Type':'application/json'}
        self.assertEqual(self.req('POST','/api/action/note','x'*65537,**hs)[0],413)
    def test_input_is_data_never_executed(self):
        hs={**self.auth(),'X-Academy-CSRF':self.server.csrf,'Content-Type':'application/json'}
        value='<script>bad()</script> $(never_execute)'
        self.assertEqual(self.req('POST','/api/action/note',json.dumps({'text':value}),**hs)[0],200)
        self.assertEqual(self.store.read()['notes'][-1]['text'],value)
    def test_no_arbitrary_file_serving(self):
        for path in ('/../AGENTS.md','/.codex/config.toml','/data/academy.sqlite'):
            self.assertEqual(self.req('GET',path,**self.auth())[0],404)


if __name__=='__main__':unittest.main()
