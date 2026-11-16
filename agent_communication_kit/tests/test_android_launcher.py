import base64, contextlib, hashlib, importlib.machinery, importlib.util, io, json, os, pathlib, shutil, subprocess, sys, tarfile, tempfile, threading, time, unittest, zlib
from unittest import mock

ROOT=pathlib.Path(__file__).resolve().parents[2]
path=ROOT/'android实验/01-NowInAndroid/一键测试.command'
loader=importlib.machinery.SourceFileLoader('android_experiment_test',str(path))
spec=importlib.util.spec_from_loader(loader.name,loader); module=importlib.util.module_from_spec(spec); loader.exec_module(module)

def executable(path,body):
 path.parent.mkdir(parents=True,exist_ok=True); path.write_text(body,encoding='utf-8'); path.chmod(0o755)

class Integration(unittest.TestCase):
 def test_old_java_is_replaced_by_downloaded_jdk(self):
  with tempfile.TemporaryDirectory() as tmp:
   base=pathlib.Path(tmp); cache=base/'cache'; cache.mkdir(); bindir=base/'bin'; bindir.mkdir()
   executable(bindir/'java',"#!/bin/sh\necho 'openjdk version \"17.0.1\"' >&2\n")
   archive=base/'fixture.tar.gz'
   with tarfile.open(archive,'w:gz') as tf:
    content=b'#!/bin/sh\necho \"openjdk version \\\"21.0.8\\\"\" >&2\n'
    entry=tarfile.TarInfo('jdk-21/bin/java'); entry.size=len(content); entry.mode=0o755
    tf.addfile(entry,io.BytesIO(content))
   def fake_download(url,dest,checksum,algorithm='sha256'): shutil.copyfile(archive,dest)
   with mock.patch.object(module,'fetch_bytes',return_value=b'a'*64), mock.patch.object(module,'download',side_effect=fake_download):
    env=module.java21({'PATH':str(bindir),'JAVA_HOME':str(base/'old')},cache)
   self.assertEqual(env['JAVA_HOME'],str(cache/'jdk21'))
   self.assertTrue(module.java_valid(cache/'jdk21/bin/java'))
 def test_download_rejects_bad_checksum(self):
  with tempfile.TemporaryDirectory() as tmp:
   target=pathlib.Path(tmp)/'artifact'
   with mock.patch.object(module.urllib.request,'urlopen',return_value=io.BytesIO(b'wrong')):
    with self.assertRaises(module.SetupError): module.download('https://example.invalid/file',target,hashlib.sha256(b'correct').hexdigest())
   self.assertFalse(target.exists())
 def test_extraction_rejects_path_traversal(self):
  with tempfile.TemporaryDirectory() as tmp:
   base=pathlib.Path(tmp); archive=base/'bad.tar.gz'; dest=base/'out'; dest.mkdir()
   with tarfile.open(archive,'w:gz') as tf:
    entry=tarfile.TarInfo('../escape'); entry.size=1; tf.addfile(entry,io.BytesIO(b'x'))
   with self.assertRaises(module.SetupError): module.safe_tar(archive,dest)
   self.assertFalse((base/'escape').exists())
 def test_cached_avdmanager_is_migrated_inside_sdk(self):
  with tempfile.TemporaryDirectory() as tmp:
   base=pathlib.Path(tmp); cache=base/'cache'; sdk=base/'sdk'; cache.mkdir(); sdk.mkdir()
   old=cache/'android-cmdline-tools/latest'
   for name in ('sdkmanager','avdmanager'): executable(old/'bin'/name,'#!/bin/sh\nexit 0\n')
   with mock.patch.object(module,'fetch_bytes',side_effect=AssertionError('cached tools should be reused')):
    manager,avd=module.prepare_sdk_manager(sdk,cache)
   self.assertEqual(pathlib.Path(avd).resolve().parents[3],sdk.resolve())
   self.assertTrue((old/'bin/avdmanager').exists())
   self.assertEqual(module.prepare_sdk_manager(sdk,cache),(manager,avd))
 def test_incomplete_user_cmdline_tools_are_preserved(self):
  with tempfile.TemporaryDirectory() as tmp:
   base=pathlib.Path(tmp); cache=base/'cache'; sdk=base/'sdk'; cache.mkdir(); sdk.mkdir()
   marker=sdk/'cmdline-tools/latest/keep.txt'; marker.parent.mkdir(parents=True); marker.write_text('keep')
   old=cache/'android-cmdline-tools/latest'
   for name in ('sdkmanager','avdmanager'): executable(old/'bin'/name,'#!/bin/sh\nexit 0\n')
   _,avd=module.prepare_sdk_manager(sdk,cache)
   self.assertEqual(marker.read_text(),'keep')
   self.assertEqual(pathlib.Path(avd).resolve().parents[3],sdk.resolve())
 def test_report_has_no_development_time_before_codex(self):
  with tempfile.TemporaryDirectory() as tmp:
   out=pathlib.Path(tmp)
   module.report(out,{'status':'未完成','failed_stage':'准备设备','detail':'测试失败'})
   report=(out/'实验报告.html').read_text()
   self.assertIn('尚未启动或未获得正式任务的有效计时',report)
   self.assertIn('准备设备',report)
   self.assertNotIn('Codex 多 Agent 正式任务</td>',report)
 def test_command_streams_output_before_completion_and_reports_heartbeat(self):
  with tempfile.TemporaryDirectory() as tmp:
   logfile=pathlib.Path(tmp)/'progress.log'; terminal=io.StringIO(); failures=[]
   def run():
    try: module.command([sys.executable,'-u','-c',"import time;print('EARLY_OUTPUT',flush=True);time.sleep(1.1);print('DONE_OUTPUT',flush=True)"],logfile=logfile,timeout=5)
    except BaseException as exc: failures.append(exc)
   with contextlib.redirect_stdout(terminal), mock.patch.object(module,'HEARTBEAT_SECONDS',.2):
    thread=threading.Thread(target=run); thread.start(); deadline=time.monotonic()+3
    while time.monotonic()<deadline:
     if logfile.exists() and '\nEARLY_OUTPUT\n' in logfile.read_text(): break
     time.sleep(.03)
    self.assertTrue(thread.is_alive(),'output must be shown while command is still running')
    self.assertIn('EARLY_OUTPUT',terminal.getvalue())
    thread.join(timeout=5)
   self.assertFalse(thread.is_alive()); self.assertFalse(failures)
   self.assertIn('[状态]',terminal.getvalue()); self.assertIn('进程仍在运行',terminal.getvalue()); self.assertIn('DONE_OUTPUT',terminal.getvalue())
   self.assertIn('DONE_OUTPUT',logfile.read_text())
 def test_command_timeout_stops_the_process(self):
  with tempfile.TemporaryDirectory() as tmp:
   logfile=pathlib.Path(tmp)/'timeout.log'; start=time.monotonic()
   with self.assertRaises(subprocess.TimeoutExpired):
    module.command([sys.executable,'-u','-c',"import time;print('started',flush=True);time.sleep(30)"],logfile=logfile,timeout=.5)
   self.assertLess(time.monotonic()-start,5)
   self.assertIn('started',logfile.read_text())
 def test_log_activity_shows_latest_event_without_message_content(self):
  with tempfile.TemporaryDirectory() as tmp:
   event=pathlib.Path(tmp)/'events.jsonl'; event.write_text(json.dumps({'type':'item.started','item':{'type':'command_execution','command':'secret command'}})+'\n')
   result=module.file_activity([('事件记录',event)])
   self.assertIn('item.started / command_execution',result); self.assertNotIn('secret command',result)
 def test_failed_command_includes_original_error(self):
  with tempfile.TemporaryDirectory() as tmp:
   with self.assertRaises(module.SetupError) as failure:
    module.command([sys.executable,'-c',"import sys; print('specific error',file=sys.stderr); sys.exit(1)"],logfile=pathlib.Path(tmp)/'run.log')
   self.assertIn('specific error',str(failure.exception))
 def test_root_shortcut_points_to_case_script(self):
  shortcut=ROOT/'一键启动多Agent实验.command'
  self.assertTrue(shortcut.is_symlink())
  self.assertEqual(shortcut.resolve(),path.resolve())
 def test_embedded_collector_matches_source(self):
  self.assertEqual(zlib.decompress(base64.b64decode(module.RUNNER)), (ROOT/'agent_communication_kit/agent_experiment.py').read_bytes())
 def test_complete_fake_pipeline(self):
  with tempfile.TemporaryDirectory() as tmp:
   base=pathlib.Path(tmp); home=base/'home'; home.mkdir(); bindir=base/'bin'; bindir.mkdir(); sdk=base/'sdk'
   (sdk/'platforms/android-36').mkdir(parents=True); (sdk/'system-images/android-34/google_apis/x86_64').mkdir(parents=True)
   executable(bindir/'magick','#!/bin/sh\nexit 0\n')
   executable(bindir/'java','#!/bin/sh\necho \'openjdk version "21.0.3"\' >&2\n')
   executable(sdk/'emulator/emulator','#!/usr/bin/python3\nimport time\ntime.sleep(100)\n')
   executable(sdk/'cmdline-tools/latest/bin/sdkmanager','#!/bin/sh\nexit 0\n')
   executable(sdk/'cmdline-tools/latest/bin/avdmanager','#!/bin/sh\nexit 0\n')
   executable(sdk/'platform-tools/adb',"#!/bin/sh\ncase \"$*\" in *getprop*) echo 1;; *instrument*) echo 'OK (3 tests)';; *) echo Success;; esac\n")
   executable(bindir/'git',f'''#!/usr/bin/env python3
import pathlib,sys
args=sys.argv[1:]
if 'clone' in args:
 p=pathlib.Path(args[-1]);p.mkdir(parents=True)
 if 'nowinandroid.git' in args[-2]:
  g=p/'gradlew';g.write_text("#!/bin/sh\\nmkdir -p app/build/outputs/apk/demo/debug app/build/outputs/apk/androidTest/demo/debug\\ntouch app/build/outputs/apk/demo/debug/app.apk app/build/outputs/apk/androidTest/demo/debug/test.apk\\n");g.chmod(0o755)
 else:
  q=p/'skills/android-bug-priority-tree';q.mkdir(parents=True);(q/'SKILL.md').write_text('fixture')
elif 'rev-parse' in args:
 if '--is-inside-work-tree' in args: print('true')
 elif '公开工作流' in str(pathlib.Path.cwd()): print('{module.FLOW_REV}')
 else: print('{module.APP_REV}')
''')
   executable(bindir/'codex','''#!/usr/bin/env python3
import json,os,pathlib,sys
if len(sys.argv)>1 and sys.argv[1]=='login': sys.exit(0)
if '--version' in sys.argv: print('codex-cli fake');sys.exit(0)
assert any('mcp_servers.mobile-mcp.command=' in arg for arg in sys.argv)
assert 'sandbox_workspace_write.network_access=true' in sys.argv
p=pathlib.Path(os.environ['CODEX_HOME'])/'sessions';p.mkdir(parents=True,exist_ok=True)
def row(t,p):return {'timestamp':'2026-11-16T10:00:00Z','type':t,'payload':p}
def write(path,rows):path.write_text(''.join(json.dumps(x,ensure_ascii=False)+'\\n' for x in rows),encoding='utf-8')
write(p/'root.jsonl',[row('session_meta',{'id':'root'}),row('response_item',{'type':'function_call','name':'spawn_agent','arguments':json.dumps({'task_name':'/root/a','message':'检查界面'},ensure_ascii=False),'call_id':'c1'}),row('response_item',{'type':'function_call','name':'wait_agent','arguments':'{}','call_id':'c2'}),row('response_item',{'type':'function_call_output','call_id':'c2','output':json.dumps({'status':{'child':{'completed':'完成检查'}}},ensure_ascii=False)})])
write(p/'child.jsonl',[row('session_meta',{'id':'child','source':{'subagent':{'thread_spawn':{'parent_thread_id':'root','agent_path':'/root/a'}}}})])
write(p/'child2.jsonl',[row('session_meta',{'id':'child2','source':{'subagent':{'thread_spawn':{'parent_thread_id':'root','agent_path':'/root/b'}}}})])
print(json.dumps({'type':'thread.started','thread_id':'root'}))
print('2026-01-01T00:00:00.000Z codex_otel.agent_communication: communication_id="one" kind="message" state="send"',file=sys.stderr)
print('2026-01-01T00:00:00.030Z codex_otel.agent_communication: communication_id="one" state="receive"',file=sys.stderr)
''')
   original=module.command
   def wrapped(argv,**kwargs):
    if len(argv)>=3 and argv[1:3]==['-m','venv']:
     pathlib.Path(argv[3]).symlink_to(pathlib.Path(sys.executable).parent.parent,target_is_directory=True); return
    if len(argv)>=4 and argv[1:4]==['-m','pip','install']: return
    if argv[0]=='npm' and '@mobilenext/mobile-mcp@1.0.17' in argv:
     dest=pathlib.Path(argv[argv.index('--prefix')+1])/'node_modules/.bin/mcp-server-mobile'; executable(dest,'#!/bin/sh\nexit 0\n'); return
    return original(argv,**kwargs)
   env={'HOME':str(home),'ANDROID_HOME':str(sdk),'ANDROID_SDK_ROOT':str(sdk),'CODEX_HOME':str(base/'codexhome'),'PATH':str(bindir)+os.pathsep+os.environ['PATH']}
   with mock.patch.dict(os.environ,env,clear=False),mock.patch.object(module,'command',side_effect=wrapped),mock.patch.object(module.os,'uname',return_value=type('U',(),{'machine':'x86_64'})()):
    self.assertEqual(module.main(),0)
   out=next((home/'codex-agent-experiments').glob('android01-*')); info=json.loads((out/'实验状态.json').read_text());
   self.assertIn('formal_elapsed_seconds',info); self.assertNotIn('phases',info)
   self.assertIn('正式开发耗时',(out/'实验报告.html').read_text())
   self.assertNotIn('检查工具与登录',(out/'实验报告.html').read_text())
   self.assertEqual(info['session_count'],3); self.assertEqual(info['recognized_messages'],2); self.assertEqual(info['telemetry_events_matched'],1)
   self.assertEqual([d['baseline_tests'] for d in info['devices']],[3,3]); self.assertTrue((out/'实验报告.html').exists())
   self.assertIn('30.000 ms',(out/'实验报告.html').read_text())

if __name__=='__main__': unittest.main(verbosity=2)
