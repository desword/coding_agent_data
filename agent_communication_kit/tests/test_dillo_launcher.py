import base64, csv, hashlib, importlib.machinery, importlib.util, io, json, os, pathlib, subprocess, sys, tarfile, tempfile, threading, time, unittest, urllib.error, urllib.request
from unittest import mock

REPO=pathlib.Path(__file__).resolve().parents[2]
SCRIPT=REPO/'多Agent-Coding场景研究/02-Dillo浏览器/Mac/一键启动.command'
loader=importlib.machinery.SourceFileLoader('dillo_launcher',str(SCRIPT))
spec=importlib.util.spec_from_loader(loader.name,loader)
mod=importlib.util.module_from_spec(spec);loader.exec_module(mod)

FAKE_CODEX=r'''#!/usr/bin/env python3
import json, os, pathlib, sys, time, urllib.request, subprocess
if '--help' in sys.argv: print('--no-daemon');raise SystemExit(0)
if '--version' in sys.argv: print('codex-fixture');raise SystemExit(0)
if 'login' in sys.argv: print('fixture');raise SystemExit(0)
if '-' not in sys.argv:
 if 'shell 工具执行' in sys.argv[-1]:
  subprocess.run(sys.argv[-1].split('\n')[-1],shell=True,check=True)
  print(json.dumps({'type':'item.completed','item':{'type':'command_execution','exit_code':0}}))
 print(json.dumps({'type':'turn.completed'}));raise SystemExit(0)
sys.stdin.read()
os.chdir(sys.argv[sys.argv.index('-C')+1])
cfg=json.loads(pathlib.Path('.experiment-build/control.json').read_text()); role=cfg['role']
def call(action,**kw):
 data={'token':cfg['token'],'action':action,'client_send_ns':time.monotonic_ns(),**kw}
 r=urllib.request.Request(cfg['url'],data=json.dumps(data).encode(),headers={'Content-Type':'application/json'})
 with urllib.request.urlopen(r,timeout=15) as h: return json.loads(h.read())
def poll():
 result=call('poll',wait=1)
 now=time.monotonic_ns()
 for m in result['messages']:call('ack',id=m['id'],client_receive_ns=now)
 return result['messages']
print(json.dumps({'type':'turn.started'}),flush=True)
print(json.dumps({'type':'item.started','item':{'id':'t1','type':'command_execution'}}),flush=True)
if role=='leader':
 for x in ('W1','W2','W3','W4','W5'):call('spawn',worker=x,text='实现和测试 '+x)
 seen=set();deadline=time.monotonic()+15
 while len(seen)<5 and time.monotonic()<deadline:
  for m in poll():seen.add(m['sender'])
 if len(seen)!=5: print(json.dumps({'type':'turn.failed','error':'messages missing'}),flush=True);raise SystemExit(2)
 call('publish',topic='download/contract',text='filename* 采用 UTF-8 的真实任务共享契约')
 seen=set();deadline=time.monotonic()+15
 while len(seen)<5 and time.monotonic()<deadline:
  for m in poll():seen.add(m['sender'])
 if len(seen)!=5: print(json.dumps({'type':'turn.failed','error':'final messages missing'}),flush=True);raise SystemExit(4)
 time.sleep(1.2)
else:
 got=poll()
 if not got: raise SystemExit(3)
 call('subscribe',topic='download/contract')
 call('send',to='leader',text='已订阅契约：'+role)
 if not poll():raise SystemExit(5)
 call('send',to='leader',text='完成真实反馈：'+role)
 time.sleep(1.3)
print(json.dumps({'type':'item.completed','item':{'id':'t1','type':'command_execution'}}),flush=True)
print(json.dumps({'type':'turn.completed','usage':{'input_tokens':10,'output_tokens':4}}),flush=True)
'''

class DilloStandaloneTest(unittest.TestCase):
 def setUp(self):
  self.t=tempfile.TemporaryDirectory();self.root=pathlib.Path(self.t.name)/'run';self.root.mkdir();(self.root/'记录').mkdir();(self.root/'测试').mkdir()
  self.repos={}
  for r in ('leader',)+mod.ROLES:
   p=self.root/('应用' if r=='leader' else 'workers/'+r);(p/'.experiment-build').mkdir(parents=True);self.repos[r]=p
  self.fake=pathlib.Path(self.t.name)/'codex';self.fake.write_text(FAKE_CODEX);self.fake.chmod(0o755)
  self.state=mod.State(self.root,self.repos,str(self.fake),os.environ.copy(),None,'cc')
  self.server=mod.serve(self.state)
 def tearDown(self):
  self.state.stop.set()
  with self.state.changed:self.state.changed.notify_all()
  self.server.shutdown();self.server.server_close();self.state.close();self.t.cleanup()
 def cli(self,role,*args,check=True):
  p=subprocess.run([sys.executable,str(SCRIPT),'--agent','--control',str(self.repos[role]/'.experiment-build/control.json'),*args],capture_output=True,text=True,timeout=20)
  if check:self.assertEqual(p.returncode,0,p.stderr)
  return p
 def test_topics_real_delivery_ack_and_boundaries(self):
  self.state.start_ns=time.monotonic_ns()
  self.cli('W1','subscribe','--topic','download/contract');self.cli('W2','subscribe','--topic','download/contract')
  sent=self.cli('leader','publish','--topic','download/contract','--text','接口变更 α')
  self.assertEqual(set(json.loads(sent.stdout)['recipients']),{'W1','W2'})
  for role in ('W1','W2'):
   msg=json.loads(self.cli(role,'poll','--wait','0').stdout)['messages']
   self.assertEqual(msg[0]['text'],'接口变更 α')
  self.cli('W2','unsubscribe','--topic','download/contract')
  second=json.loads(self.cli('leader','publish','--topic','download/contract','--text','仅发给当前订阅者').stdout)
  self.assertEqual(second['recipients'],['W1']);self.cli('W1','poll','--wait','0')
  self.assertEqual(json.loads(self.cli('W2','poll','--wait','0').stdout)['messages'],[])
  bad=self.cli('W1','send','--to','W2','--text','禁止直连',check=False);self.assertNotEqual(bad.returncode,0)
  self.state.end_ns=time.monotonic_ns();mod.make_report(self.state,{'status':'test','detail':'','checks':{}})
  with (self.root/'记录/消息明细.csv').open(encoding='utf-8-sig',newline='') as f:rows=list(csv.DictReader(f))
  self.assertEqual(len(rows),3);self.assertTrue(all(r['delivery_status']=='客户端已领取并确认' for r in rows))
  self.assertTrue(all(r['sender']=='leader' and float(r['sender_to_client_ms'])>=0 for r in rows))
  with (self.root/'记录/每秒通信速率.csv').open(encoding='utf-8-sig',newline='') as f:bw=list(csv.DictReader(f))
  self.assertTrue(any(int(r['delivered_messages']) for r in bw))
  self.assertEqual(sum(int(r['leader_to_worker_offered_copies']) for r in bw),3)
  self.assertEqual(sum(int(r['leader_to_worker_offered_bytes']) for r in bw),2*len('接口变更 α'.encode())+len('仅发给当前订阅者'.encode()))
  self.assertEqual(sum(int(r['worker_to_leader_offered_bytes']) for r in bw),0)
  self.assertTrue((self.root/'记录/系统内存采样.csv').exists())
 def test_mac_host_counters_are_collected_without_assuming_free_memory(self):
  def command(args,**kwargs):
   values={'hw.physicalcpu':'4','hw.memsize':str(32*1024**3),'vm.swapusage':'total = 1024M  used = 12M  free = 1012M'}
   output='Mach Virtual Memory Statistics: (page size of 4096 bytes)\nPages free: 120.\n' if args[0]=='vm_stat' else values[args[-1]]
   return subprocess.CompletedProcess(args,0,output,'')
  with mock.patch.object(mod.sys,'platform','darwin'),mock.patch.object(mod.subprocess,'run',side_effect=command):
   host=mod.host_profile();snapshot=mod.system_snapshot()
  self.assertEqual(host['physical_cpus'],4);self.assertEqual(host['memory_bytes'],32*1024**3)
  self.assertIn('used = 12M',snapshot['swap_usage']);self.assertIn('Pages free: 120.',snapshot['vm_stat'])
 def test_directional_offered_load_includes_unacknowledged_messages(self):
  self.state.start_ns=time.monotonic_ns()
  self.cli('W1','send','--to','leader','--text','等待 Leader 领取')
  self.state.end_ns=time.monotonic_ns();mod.make_report(self.state,{'status':'test','checks':{}})
  with (self.root/'记录/每秒通信速率.csv').open(encoding='utf-8-sig',newline='') as f:rows=list(csv.DictReader(f))
  self.assertEqual(sum(int(r['worker_to_leader_offered_bytes']) for r in rows),len('等待 Leader 领取'.encode()))
  self.assertEqual(sum(int(r['worker_to_leader_offered_copies']) for r in rows),1)
  self.assertEqual(sum(int(r['delivered_messages']) for r in rows),0)
 def test_independent_processes_and_fake_is_not_success(self):
  self.state.start_ns=time.monotonic_ns();self.state.launch('leader','fixture prompt')
  sampler=threading.Thread(target=mod.sample_resources,args=(self.state,.3),daemon=True);sampler.start()
  self.state.procs['leader'].wait(timeout=25)
  for p in list(self.state.procs.values()):p.wait(timeout=10)
  for watcher in self.state.watchers:watcher.join(timeout=5)
  self.state.stop.set();sampler.join(timeout=5);self.state.end_ns=time.monotonic_ns()
  self.assertEqual(set(self.state.procs),{'leader',*mod.ROLES})
  self.assertEqual(len({p.pid for p in self.state.procs.values()}),6)
  self.assertTrue(all(v.get('terminal_event')=='turn.completed' for v in self.state.runs.values()))
  self.assertEqual({m['sender'] for m in self.state.messages.values() if m['sender']!='leader'},set(mod.ROLES))
  self.assertTrue(any(x['agent']=='W1' for x in self.state.sample_rows))
  ok,detail=mod.completion_result(self.state,{'真实功能':{'passed':False}});self.assertFalse(ok);self.assertIn('未全部通过',detail)
  ok,_=mod.completion_result(self.state,{});self.assertFalse(ok)
  ok,detail=mod.completion_result(self.state,{'真实功能':{'passed':True}});self.assertFalse(ok);self.assertIn('最终审查交互未确认',detail)
  end=self.state.runs['W5']['end_ns'];t=max(self.state.runs[r]['end_ns'] for r in ('W1','W2','W3','W4'))+1
  self.state.runs['W5']['end_ns']=t+10
  self.state.messages['review-start']={'sender':'leader','kind':'message','deliveries':{'W5':{'client_receive_ns':t}}}
  self.state.messages['review-result']={'sender':'W5','kind':'message','service_recv_ns':t+2,'deliveries':{'leader':{'client_receive_ns':t+3}}}
  event_count=len(self.state.events)
  for role in ('W1','W2','W3','W4'):
   reply=next(m['service_recv_ns'] for m in self.state.messages.values() if m.get('sender')==role)
   self.state.events.append({'event':'git_operation','agent':role,'operation':'提交工作','exit_code':0,'mono_ns':reply-1})
  ok,_=mod.completion_result(self.state,{'真实功能':{'passed':True}});self.assertTrue(ok)
  del self.state.events[event_count:];del self.state.messages['review-start'];del self.state.messages['review-result'];self.state.runs['W5']['end_ns']=end
  mod.make_report(self.state,{'status':'未完成','detail':'fixture has no code changes','checks':{'真实功能':{'passed':False}}})
  self.assertIn('未完成',(self.root/'实验报告.html').read_text())
 def test_otlp_histograms_do_not_double_count(self):
  path=self.root/'记录/W1-模型指标.jsonl'
  def point(n,total):return {'payload':{'resourceMetrics':[{'scopeMetrics':[{'metrics':[{'name':'codex.responses_api_inference_time.duration_ms','histogram':{'dataPoints':[{'attributes':[],'count':str(n),'sum':total,'min':1,'max':4}]}}]}]}]}}
  path.write_text(json.dumps(point(1,2))+'\n'+json.dumps(point(2,6))+'\n')
  rows=mod.metrics_from_otlp(path,'W1');self.assertEqual(rows[0]['count'],2);self.assertEqual(rows[0]['average_ms'],3)
 def test_local_otel_endpoint_and_setup_exclusion(self):
  url=self.state.metrics_endpoints['W1']
  value={'resourceMetrics':[{'scopeMetrics':[{'metrics':[{'name':'codex.responses_api_inference_time.duration_ms','histogram':{'dataPoints':[{'count':'1','sum':42}]}}]}]}]}
  def send():
   req=urllib.request.Request(url,data=json.dumps(value).encode(),headers={'Content-Type':'application/json'})
   with urllib.request.urlopen(req,timeout=5) as r:self.assertEqual(r.status,200)
  send();path=self.root/'记录/W1-模型指标.jsonl';self.assertFalse(path.exists())
  self.state.start_ns=time.monotonic_ns();send();self.assertTrue(path.exists())
  self.assertEqual(mod.metrics_from_otlp(path,'W1')[0]['average_ms'],42)
 def test_codex_error_item_is_reported_and_secret_redacted(self):
  path=self.root/'记录/model-error.jsonl'
  path.write_text(json.dumps({'type':'item.completed','item':{'type':'error','message':'model_not_found token=abc123secret'}})+'\n')
  message=mod.model_error(path);self.assertIn('model_not_found',message);self.assertNotIn('abc123secret',message)
 def test_no_worker_diagnostic_surfaces_leader_message_and_redacts_secret(self):
  path=self.root/'记录/leader-events.jsonl'
  path.write_text(json.dumps({'type':'item.completed','item':{'type':'agent_message','text':'无法执行工具 token=abc123secret'}})+'\n')
  result=mod.leader_diagnostics(self.root/'记录')
  self.assertIn('无法执行工具',result);self.assertNotIn('abc123secret',result)
 def test_shell_preflight_requires_real_marker(self):
  mod.probe_shell(self.state)
  self.assertFalse((self.repos['leader']/'.experiment-build/shell-preflight.txt').exists())
  self.fake.write_text('#!/usr/bin/env python3\nprint(\'{"type":"turn.completed"}\')\n');self.fake.chmod(0o755)
  with self.assertRaises(mod.ExperimentError):mod.probe_shell(self.state)
 def test_official_npm_pair_and_integrity(self):
  data=io.BytesIO()
  with tarfile.open(fileobj=data,mode='w:gz') as tf:
   for name,content in [('package/vendor/x86_64-apple-darwin/codex/codex',b'cli'),('package/vendor/x86_64-apple-darwin/codex/codex-code-mode-host',b'host')]:
    entry=tarfile.TarInfo(name);entry.size=len(content);tf.addfile(entry,io.BytesIO(content))
  payload=data.getvalue();integrity='sha512-'+base64.b64encode(hashlib.sha512(payload).digest()).decode()
  latest=json.dumps({'optionalDependencies':{'@openai/codex-darwin-x64':'npm:@openai/codex@0.169.0-darwin-x64'}}).encode()
  metadata=json.dumps({'name':'@openai/codex','version':'0.169.0-darwin-x64','dist':{'tarball':'https://registry.npmjs.org/a.tgz','integrity':integrity}}).encode()
  with mock.patch.object(mod.urllib.request,'urlopen',side_effect=[io.BytesIO(latest),io.BytesIO(metadata),io.BytesIO(payload)]):
   mod.fetch_codex_npm_pair(self.root,'x86_64')
  self.assertEqual((self.root/'codex').read_bytes(),b'cli');self.assertEqual((self.root/'codex-code-mode-host').read_bytes(),b'host')
  self.assertTrue(os.access(self.root/'codex-code-mode-host',os.X_OK))
  bad=json.dumps({'name':'@openai/codex','version':'0.169.0-darwin-x64','dist':{'tarball':'https://registry.npmjs.org/a.tgz','integrity':'sha512-invalid'}}).encode()
  with mock.patch.object(mod.urllib.request,'urlopen',side_effect=[io.BytesIO(latest),io.BytesIO(bad),io.BytesIO(payload)]):
   with self.assertRaises(mod.ExperimentError):mod.fetch_codex_npm_pair(self.root,'x86_64')
 def test_preparation_log_records_errors_without_secrets(self):
  path=self.root/'准备过程.log'
  with mock.patch.object(mod,'PREPARATION_LOG',path):mod.emit('[失败] token=abc123secret')
  self.assertIn('[失败]',path.read_text());self.assertNotIn('abc123secret',path.read_text())
 def test_invalid_api_key_uses_isolated_login_for_retry(self):
  self.fake.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
home=os.environ.get("CODEX_HOME", "")
if sys.argv[1:]==["login", "status"]:
 raise SystemExit(0 if not home or (pathlib.Path(home)/"logged-in").exists() else 1)
if sys.argv[1:]==["login"]:
 pathlib.Path(home, "logged-in").touch();raise SystemExit(0)
if not home or os.environ.get("OPENAI_API_KEY"):
 print(json.dumps({"type":"turn.failed","error":{"message":"invalid_api_key Incorrect API key"}}));raise SystemExit(1)
print(json.dumps({"type":"turn.completed"}))
''');self.fake.chmod(0o755)
  with mock.patch.dict(os.environ,{'OPENAI_API_KEY':'invalid-fixture'},clear=False):
   os.environ.pop('CODEX_HOME',None)
   self.assertIsNone(mod.check_auth(str(self.fake),self.repos['leader'],self.root/'记录'))
   self.assertNotIn('OPENAI_API_KEY',os.environ)
   self.assertTrue(pathlib.Path(os.environ['CODEX_HOME'],'logged-in').exists())

class DilloCheckoutTest(unittest.TestCase):
 def test_first_fetch_and_cached_clones(self):
  with tempfile.TemporaryDirectory() as tmp:
   base=pathlib.Path(tmp);source=base/'source';source.mkdir();(source/'test/unit').mkdir(parents=True);(source/'dlib').mkdir();(source/'src').mkdir()
   (source/'test/unit/disposition.c').write_text('struct testcase {int x;};\nstruct testcase cases[] = {\n{1},\n};\nstatic int equal(void){return 1;}\nint main(void){return !equal();}\n')
   (source/'dlib/dlib.c').write_text('int dlib_fixture;\n')
   (source/'src/misc.h').write_text('/* fixture */\n')
   subprocess.run(['git','init','-q',str(source)],check=True)
   subprocess.run(['git','-C',str(source),'add','.'],check=True)
   subprocess.run(['git','-C',str(source),'-c','user.name=Test','-c','user.email=test@localhost','commit','-qm','fixture'],check=True)
   rev=subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip()
   old_url,old_rev=mod.APP_URL,mod.APP_REV;mod.APP_URL=str(source);mod.APP_REV=rev
   try:
    cache=base/'cache';cache.mkdir();root=base/'运行一';root.mkdir();(root/'测试').mkdir()
    repos=mod.prepare_repos(cache,root,root/'prepare.log')
    self.assertEqual(len(repos),6);self.assertEqual(mod.baseline(repos['leader'],'cc',root/'prepare.log'),1)
    (repos['W1']/'src/misc.h').write_text('/* worker patch */\n')
    state=mod.State(root,repos,'unused',os.environ.copy(),None,'cc');server=mod.serve(state)
    try:
     def client(role,*args):
      p=subprocess.run([sys.executable,str(SCRIPT),'--agent','--control',str(repos[role]/'.experiment-build/control.json'),*args],capture_output=True,text=True,timeout=30)
      self.assertEqual(p.returncode,0,p.stderr);return json.loads(p.stdout)
     commit=client('W1','commit');self.assertTrue(commit['commit'])
     merged=client('leader','integrate','W1');self.assertEqual(merged['source_commit'],commit['commit'])
     self.assertEqual((repos['leader']/'src/misc.h').read_text(),'/* worker patch */\n')
     self.assertTrue(any(x['event']=='git_operation' for x in state.events))
     (repos['W2']/'src/misc.h').write_text('/* not W2 scope */\n')
     bad=subprocess.run([sys.executable,str(SCRIPT),'--agent','--control',str(repos['W2']/'.experiment-build/control.json'),'commit'],capture_output=True,text=True,timeout=30)
     self.assertNotEqual(bad.returncode,0)
     self.assertEqual(subprocess.check_output(['git','-C',str(repos['W2']),'rev-parse','HEAD'],text=True).strip(),rev)
    finally:server.shutdown();server.server_close();state.close()
    mod.APP_URL=str(base/'不存在的远端');second=base/'运行二';second.mkdir()
    cloned=mod.prepare_repos(cache,second,second/'prepare.log')
    self.assertEqual(len(cloned),6)
    for path in cloned.values():
     self.assertEqual(subprocess.check_output(['git','-C',str(path),'rev-parse','HEAD'],text=True).strip(),rev)
   finally:mod.APP_URL,mod.APP_REV=old_url,old_rev

 def test_full_one_click_run_keeps_failed_work_incomplete(self):
  with tempfile.TemporaryDirectory() as tmp:
   base=pathlib.Path(tmp);source=base/'source';source.mkdir();(source/'test/unit').mkdir(parents=True);(source/'dlib').mkdir()
   (source/'test/unit/disposition.c').write_text('struct testcase {int x;};\nstruct testcase cases[] = {\n{1},\n};\nstatic int equal(void){return 1;}\nint main(void){return !equal();}\n')
   (source/'dlib/dlib.c').write_text('int dlib_fixture;\n')
   subprocess.run(['git','init','-q',str(source)],check=True);subprocess.run(['git','-C',str(source),'add','.'],check=True)
   subprocess.run(['git','-C',str(source),'-c','user.name=Test','-c','user.email=test@localhost','commit','-qm','fixture'],check=True)
   rev=subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip()
   bindir=base/'bin';bindir.mkdir();fake=bindir/'codex';fake.write_text(FAKE_CODEX);fake.chmod(0o755)
   old_url,old_rev=mod.APP_URL,mod.APP_REV;mod.APP_URL=str(source);mod.APP_REV=rev
   try:
    with mock.patch.object(pathlib.Path,'home',return_value=base), mock.patch.dict(os.environ,{'PATH':str(bindir)+os.pathsep+os.environ['PATH']}):
     self.assertEqual(mod.main(),1)
    runs=list((base/'codex-agent-experiments').glob('browser01-*'));self.assertEqual(len(runs),1)
    status=json.loads((runs[0]/'实验状态.json').read_text())
    self.assertEqual(status['status'],'未完成');self.assertGreater(status['formal_elapsed_seconds'],0)
    self.assertEqual(len(status['runs']),6);self.assertEqual(status['delivery_acked'],20)
    self.assertTrue((runs[0]/'实验报告.html').exists());self.assertTrue((runs[0]/'记录/每Agent资源.csv').exists())
   finally:mod.APP_URL,mod.APP_REV=old_url,old_rev

def load_tests(loader,tests,pattern):return tests
if __name__=='__main__':unittest.main()
