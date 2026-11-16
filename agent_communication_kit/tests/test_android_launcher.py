import base64, contextlib, hashlib, importlib.machinery, importlib.util, io, json, os, pathlib, shutil, subprocess, sys, tarfile, tempfile, threading, time, types, unittest, zlib
from unittest import mock

ROOT=pathlib.Path(__file__).resolve().parents[2]
path=ROOT/'android实验/01-NowInAndroid/一键测试.command'
loader=importlib.machinery.SourceFileLoader('android_experiment_test',str(path))
spec=importlib.util.spec_from_loader(loader.name,loader); module=importlib.util.module_from_spec(spec); loader.exec_module(module)

def executable(path,body):
 path.parent.mkdir(parents=True,exist_ok=True); path.write_text(body,encoding='utf-8'); path.chmod(0o755)

class Integration(unittest.TestCase):
 def test_gradle_copies_old_downloads_into_independent_shared_cache(self):
  with tempfile.TemporaryDirectory() as tmp:
   base=pathlib.Path(tmp);cache=base/'cache';cache.mkdir();root=base/'android01-20261116-2';root.mkdir()
   previous=base/'android01-20261116-1';previous.mkdir();old=previous/'Gradle缓存'
   artifact=old/'caches/modules-2/files-2.1/group/artifact/1/hash/test.jar';artifact.parent.mkdir(parents=True);artifact.write_text('artifact')
   metadata=old/'caches/modules-2/metadata-2.107/index.bin';metadata.parent.mkdir(parents=True);metadata.write_text('do not copy active index')
   dist=old/'wrapper/dists/gradle-9/binhash';dist.mkdir(parents=True);(dist/'gradle.zip.ok').write_text('');(dist/'gradle.zip').write_text('zip');(dist/'gradle.zip.lck').write_text('lock')
   (previous/'实验状态.json').write_text(json.dumps({'app_commit':module.APP_REV,'finished_utc':'2026-11-16T00:00:00Z'}))
   result=module.gradle_cache_home(root,cache);self.assertEqual(result,cache/'Gradle缓存')
   self.assertTrue(previous.exists());shutil.rmtree(previous)
   self.assertEqual((result/'caches/modules-2/files-2.1/group/artifact/1/hash/test.jar').read_text(),'artifact')
   self.assertTrue((result/'wrapper/dists/gradle-9/binhash/gradle.zip.ok').exists())
   self.assertFalse((result/'wrapper/dists/gradle-9/binhash/gradle.zip.lck').exists())
   self.assertFalse((result/'caches/modules-2/metadata-2.107').exists())
   self.assertEqual(module.gradle_cache_home(root,cache),result)
 def test_later_finished_legacy_run_is_migrated_on_next_start(self):
  with tempfile.TemporaryDirectory() as tmp:
   base=pathlib.Path(tmp);cache=base/'cache';cache.mkdir();root=base/'android01-3';root.mkdir();old=base/'android01-1';old.mkdir()
   artifact=old/'Gradle缓存/caches/modules-2/files-2.1/group/artifact/1/hash/a.jar';artifact.parent.mkdir(parents=True);artifact.write_text('later')
   shared=module.gradle_cache_home(root,cache)
   self.assertFalse((shared/'caches/modules-2/files-2.1/group/artifact/1/hash/a.jar').exists())
   (old/'实验状态.json').write_text(json.dumps({'app_commit':module.APP_REV,'finished_utc':'later'}))
   self.assertEqual(module.gradle_cache_home(root,cache),shared)
   self.assertEqual((shared/'caches/modules-2/files-2.1/group/artifact/1/hash/a.jar').read_text(),'later')
 def test_python_report_environment_is_reused_across_batches(self):
  with tempfile.TemporaryDirectory() as tmp:
   cache=pathlib.Path(tmp);log=cache/'test.log';calls=[]
   def fake_command(argv,**kwargs):
    calls.append(argv)
    if argv[1:3]==['-m','venv']: executable(pathlib.Path(argv[3])/'bin/python','#!/bin/sh\nexit 0\n')
    return types.SimpleNamespace(returncode=0)
   with mock.patch.object(module,'command',side_effect=fake_command),mock.patch.object(module,'python_env_valid',side_effect=lambda py:py.exists()):
    first=module.prepare_python_env(cache,{},log);second=module.prepare_python_env(cache,{},log)
   self.assertEqual(first,second);self.assertTrue(first.is_relative_to(cache));self.assertEqual(len(calls),2)
 def test_codex_tool_migrates_and_survives_old_run_deletion(self):
  with tempfile.TemporaryDirectory() as tmp:
   base=pathlib.Path(tmp);cache=base/'cache';cache.mkdir();root=base/'android01-2';root.mkdir();previous=base/'android01-1';previous.mkdir()
   (previous/'实验状态.json').write_text(json.dumps({'app_commit':module.APP_REV,'finished_utc':'done'}))
   executable(previous/'codex工具/node_modules/.bin/codex','#!/bin/sh\necho codex-cli-fake\n')
   env={'PATH':'/usr/bin:/bin'}
   with mock.patch.object(module,'command',side_effect=AssertionError('should migrate')):
    result=module.ensure_codex(env,cache,base/'test.log',root)
   shutil.rmtree(previous)
   binary=pathlib.Path(result['PATH'].split(os.pathsep)[0])/'codex'
   self.assertTrue(binary.is_file());self.assertTrue(binary.resolve().is_relative_to(cache))
   self.assertEqual(subprocess.check_output([str(binary),'--version'],text=True).strip(),'codex-cli-fake')
 def test_shared_cache_lock_serializes_installation(self):
  with tempfile.TemporaryDirectory() as tmp:
   cache=pathlib.Path(tmp);held=threading.Event();release=threading.Event();acquired=threading.Event();errors=[]
   def first():
    try:
     with module.cache_lock(cache,'example'):held.set();release.wait(3)
    except BaseException as exc:errors.append(exc)
   def second():
    try:
     with module.cache_lock(cache,'example'):acquired.set()
    except BaseException as exc:errors.append(exc)
   a=threading.Thread(target=first);b=threading.Thread(target=second);a.start();self.assertTrue(held.wait(2));b.start()
   try:self.assertFalse(acquired.wait(.2))
   finally:release.set();a.join(3);b.join(3)
   self.assertTrue(acquired.is_set());self.assertFalse(errors)
 def test_mobile_tool_migrates_and_survives_old_run_deletion(self):
  with tempfile.TemporaryDirectory() as tmp:
   base=pathlib.Path(tmp);cache=base/'cache';cache.mkdir();root=base/'android01-2';root.mkdir();previous=base/'android01-1';previous.mkdir()
   (previous/'实验状态.json').write_text(json.dumps({'app_commit':module.APP_REV,'finished_utc':'done'}))
   old=previous/'设备工具';modules=old/'node_modules';package=modules/'@mobilenext/mobile-mcp';package.mkdir(parents=True);(package/'package.json').write_text(json.dumps({'version':'1.0.17'}));executable(package/'lib/index.js','#!/bin/sh\nexit 0\n')
   native=modules/'@mobilenext/mobilecli-darwin-arm64/mobilecli-darwin-arm64';executable(native,'#!/bin/sh\nexit 0\n')
   bins=modules/'.bin';bins.mkdir();(bins/'mcp-server-mobile').symlink_to('../@mobilenext/mobile-mcp/lib/index.js')
   with mock.patch.object(module.subprocess,'run',return_value=types.SimpleNamespace(returncode=0,stdout='darwin-arm64\n')),mock.patch.object(module,'command',side_effect=AssertionError('should migrate')):
    first=module.prepare_mobile_tool(root,cache,{},base/'test.log');shutil.rmtree(previous);second=module.prepare_mobile_tool(root,cache,{},base/'test.log')
   self.assertEqual(first,second);self.assertTrue(first.is_file());self.assertTrue(first.resolve().is_relative_to(cache))
 def test_low_disk_space_does_not_consume_or_delete_legacy_cache(self):
  with tempfile.TemporaryDirectory() as tmp:
   base=pathlib.Path(tmp);cache=base/'cache';cache.mkdir();root=base/'android01-2';root.mkdir();old=base/'android01-1';old.mkdir()
   (old/'实验状态.json').write_text(json.dumps({'app_commit':module.APP_REV,'finished_utc':'done'}))
   entry=old/'Gradle缓存/caches/build-cache-1'/('a'*32);entry.parent.mkdir(parents=True);entry.write_text('original')
   with mock.patch.object(module.shutil,'disk_usage',return_value=types.SimpleNamespace(free=100)):
    shared=module.gradle_cache_home(root,cache)
   self.assertEqual(entry.read_text(),'original');self.assertFalse((shared/'caches/build-cache-1'/('a'*32)).exists())
   marker=json.loads((shared/'.旧批次下载已迁移').read_text());self.assertNotIn(old.name,marker['runs'])
 def test_build_task_cache_migrates_even_after_older_marker(self):
  with tempfile.TemporaryDirectory() as tmp:
   base=pathlib.Path(tmp);cache=base/'cache';cache.mkdir();root=base/'android01-2';root.mkdir();old=base/'android01-1';old.mkdir()
   (old/'实验状态.json').write_text(json.dumps({'app_commit':module.APP_REV,'finished_utc':'done'}))
   oldcache=old/'Gradle备用配置/caches/build-cache-1';oldcache.mkdir(parents=True);key='a'*32;(oldcache/key).write_text('cached output');(oldcache/'build-cache-1.lock').write_text('lock')
   shared=cache/'Gradle缓存';shared.mkdir();(shared/'.旧批次下载已迁移').write_text(json.dumps({'version':1,'runs':['android01-1']}))
   self.assertEqual(module.gradle_cache_home(root,cache),shared)
   self.assertEqual((shared/'caches/build-cache-1'/key).read_text(),'cached output');self.assertFalse((shared/'caches/build-cache-1/build-cache-1.lock').exists());self.assertTrue((oldcache/key).is_file())
   mirror=module.gradle_mirror_home(root,shared)
   self.assertEqual((mirror/'caches/build-cache-1').resolve(),(shared/'caches/build-cache-1').resolve())
 def test_packaging_failure_retries_same_workspace_with_stacktrace(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=pathlib.Path(tmp);shared=root/'shared';shared.mkdir();log=root/'build.log';info={};calls=[]
   def fake_command(args,**kwargs):
    calls.append((args,kwargs))
    with log.open('a') as f:f.write("Execution failed for task ':app:packageDemoDebug'\nA failure occurred in PackageAndroidArtifact$IncrementalSplitterRunnable\n" if len(calls)==1 else 'BUILD SUCCESSFUL\n')
    return types.SimpleNamespace(returncode=1 if len(calls)==1 else 0)
   env={'GRADLE_USER_HOME':str(shared)}
   with mock.patch.object(module,'command',side_effect=fake_command):module.build_gradle_with_retry(root,root,env,log,info)
   self.assertEqual(len(calls),2);self.assertTrue(info['gradle_packaging_retry']);self.assertEqual(info['gradle_attempts'],2)
   self.assertTrue(all('--stacktrace' in x[0] and x[1]['cwd']==root for x in calls));self.assertEqual(calls[0][1]['env']['GRADLE_USER_HOME'],calls[1][1]['env']['GRADLE_USER_HOME'])
 def test_packaging_root_cause_is_reported_without_unsafe_retry(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=pathlib.Path(tmp);shared=root/'shared';shared.mkdir();log=root/'build.log';calls=[]
   output="* What went wrong:\nExecution failed for task ':app:packageDemoDebug'.\n> PackageAndroidArtifact$IncrementalSplitterRunnable\n* Try:\nSee documentation\n* Exception is:\nCaused by: java.io.IOException: No space left on device\n"
   def fake_command(args,**kwargs):calls.append(args);log.write_text(output);return types.SimpleNamespace(returncode=1)
   with mock.patch.object(module,'command',side_effect=fake_command):
    with self.assertRaises(module.SetupError) as error:module.build_gradle_with_retry(root,root,{'GRADLE_USER_HOME':str(shared)},log,{})
   self.assertEqual(len(calls),1);self.assertIn('Caused by: java.io.IOException: No space left on device',str(error.exception))
 def test_failure_summary_keeps_root_cause_after_long_paths(self):
  output='* What went wrong:\n> PackageAndroidArtifact$IncrementalSplitterRunnable\n* Try:\nsee log\n* Exception is:\nCaused by: java.io.IOException: '+('long-path/'*100)+' No space left on device\n'
  result=module.gradle_failure_summary(output)
  self.assertIn('IncrementalSplitterRunnable',result);self.assertIn('No space left on device',result)
 def test_gradle_maven_tls_failure_switches_official_mirror(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=pathlib.Path(tmp);shared=root/'shared';shared.mkdir();log=root/'build.log';env={'GRADLE_USER_HOME':str(shared)};info={};calls=[]
   def fake_command(args,**kwargs):
    calls.append(kwargs['env'].copy())
    with log.open('a') as f:f.write("Could not get resource 'https://repo.maven.apache.org/maven2/artifact.jar'\nIllegal packet size: 49729\n" if len(calls)==1 else 'BUILD SUCCESSFUL\n')
    return types.SimpleNamespace(returncode=1 if len(calls)==1 else 0)
   with mock.patch.object(module,'command',side_effect=fake_command):module.build_gradle_with_retry(root,root,env,log,info)
   self.assertEqual(len(calls),2);self.assertEqual(info['gradle_attempts'],2);self.assertEqual(info['maven_central_mirror'],'https://repo1.maven.org/maven2/')
   home=pathlib.Path(env['GRADLE_USER_HOME']);self.assertEqual((home/'caches/modules-2').resolve(),(shared/'caches/modules-2').resolve())
   self.assertFalse((home/'caches').is_symlink());self.assertTrue((home/'init.d/maven-central-fallback.gradle').is_file())
 def test_gradle_non_network_error_does_not_retry(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=pathlib.Path(tmp);shared=root/'shared';shared.mkdir();log=root/'build.log';calls=[]
   def fake_command(args,**kwargs):calls.append(args);log.write_text('Compilation error: unresolved reference X\n');return types.SimpleNamespace(returncode=1)
   with mock.patch.object(module,'command',side_effect=fake_command):
    with self.assertRaises(module.SetupError):module.build_gradle_with_retry(root,root,{'GRADLE_USER_HOME':str(shared)},log,{})
   self.assertEqual(len(calls),1)
 def test_gradle_certificate_error_is_not_ignored(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=pathlib.Path(tmp);shared=root/'shared';shared.mkdir();log=root/'build.log';calls=[]
   def fake_command(args,**kwargs):calls.append(args);log.write_text('PKIX path building failed: certificate has expired\n');return types.SimpleNamespace(returncode=1)
   with mock.patch.object(module,'command',side_effect=fake_command):
    with self.assertRaises(module.SetupError):module.build_gradle_with_retry(root,root,{'GRADLE_USER_HOME':str(shared)},log,{})
   self.assertEqual(len(calls),1)
 def test_gradle_http_proxy_preserves_environment_and_rejects_credentials(self):
  env={'JAVA_TOOL_OPTIONS':'-Xmx2g','OTHER':'unchanged'}
  with mock.patch.object(module.urllib.request,'getproxies',return_value={'https':'http://127.0.0.1:8080','no':'localhost,.example.com'}):
   result=module.gradle_proxy_environment(env)
  self.assertEqual(env['JAVA_TOOL_OPTIONS'],'-Xmx2g');self.assertIn('-Dhttps.proxyHost=127.0.0.1',result['JAVA_TOOL_OPTIONS']);self.assertIn('*.example.com',result['JAVA_TOOL_OPTIONS']);self.assertEqual(result['OTHER'],'unchanged')
  with mock.patch.object(module.urllib.request,'getproxies',return_value={'https':'http://user:password@127.0.0.1:8080'}):self.assertIsNone(module.gradle_proxy_environment(env))
 def test_expired_proxy_certificate_is_not_retried_with_system_trust(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=pathlib.Path(tmp);shared=root/'shared';shared.mkdir();log=root/'build.log';calls=[]
   failures=['repo.maven.apache.org Illegal packet size: 49729','repo1.maven.org Connection reset','PKIX path building failed: certificate has expired']
   def fake_command(args,**kwargs):
    calls.append(kwargs['env'].copy())
    with log.open('a') as f:f.write(failures[len(calls)-1]+'\n')
    return types.SimpleNamespace(returncode=1)
   with mock.patch.object(module,'command',side_effect=fake_command),mock.patch.object(module.urllib.request,'getproxies',return_value={'https':'http://127.0.0.1:8080'}),mock.patch.object(module,'gradle_system_trust_environment') as trust:
    with self.assertRaises(module.SetupError):module.build_gradle_with_retry(root,root,{'GRADLE_USER_HOME':str(shared)},log,{})
   self.assertEqual(len(calls),3);trust.assert_not_called()
 def test_gradle_respects_existing_trust_store(self):
  self.assertIsNone(module.gradle_system_trust_environment({'JAVA_TOOL_OPTIONS':'-Djavax.net.ssl.trustStore=/existing'}))
 def test_gradle_proxy_can_use_existing_system_trust_after_pkix(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=pathlib.Path(tmp);shared=root/'shared';shared.mkdir();log=root/'build.log';env={'GRADLE_USER_HOME':str(shared)};info={};calls=[]
   failures=["repo.maven.apache.org Illegal packet size: 49729",'repo1.maven.org Connection reset','PKIX path building failed: unable to find valid certification path','BUILD SUCCESSFUL']
   def fake_command(args,**kwargs):
    calls.append(kwargs['env'].copy())
    with log.open('a') as f:f.write(failures[len(calls)-1]+'\n')
    return types.SimpleNamespace(returncode=0 if len(calls)==4 else 1)
   def trusted(e):return {**e,'JAVA_TOOL_OPTIONS':e['JAVA_TOOL_OPTIONS']+' -Djavax.net.ssl.trustStore=/trusted/system'}
   with mock.patch.object(module,'command',side_effect=fake_command),mock.patch.object(module.urllib.request,'getproxies',return_value={'https':'http://127.0.0.1:8080'}),mock.patch.object(module,'gradle_system_trust_environment',side_effect=trusted):module.build_gradle_with_retry(root,root,env,log,info)
   self.assertEqual(len(calls),4);self.assertTrue(info['gradle_system_trust']);self.assertIn('-Djavax.net.ssl.trustStore=',calls[-1]['JAVA_TOOL_OPTIONS'])
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
 def test_codex_error_from_json_with_empty_stderr_is_reported(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=pathlib.Path(tmp); record=root/'记录'; record.mkdir()
   (record/'codex-stderr.log').write_text('')
   (record/'codex-events.jsonl').write_text(json.dumps({'type':'turn.failed','error':{'message':'Model is not available for this account; token=abc123secret'}})+'\n')
   result=module.codex_failure(root,1)
   self.assertIn('Model is not available for this account',result)
   self.assertNotIn('abc123secret',result); self.assertIn('[已隐藏]',result)
 def test_codex_error_from_stderr_when_events_are_empty(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=pathlib.Path(tmp); record=root/'记录'; record.mkdir()
   (record/'codex-events.jsonl').write_text('')
   (record/'codex-stderr.log').write_text('ERROR unable to reach service: Proxy 403\n')
   self.assertIn('Proxy 403',module.codex_failure(root,1))
 def test_no_codex_diagnostic_does_not_invent_cause(self):
  with tempfile.TemporaryDirectory() as tmp:
   result=module.codex_failure(pathlib.Path(tmp),1)
   self.assertIn('未能在事件和错误日志中提取原因',result); self.assertIn('codex-events.jsonl',result)
 def test_invalid_openai_key_guides_isolated_login_and_rechecks(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=pathlib.Path(tmp); cache=root/'cache';cache.mkdir();calls=[]
   env={'PATH':'/bin','OPENAI_API_KEY':'sk-or-v1-fake','CODEX_API_KEY':'another-fake','CODEX_HOME':'/original','CUSTOM_SENTINEL':'keep'}
   def fake_command(argv,**kwargs):
    calls.append((argv,kwargs))
    if '--skip-git-repo-check' in argv:
     log=kwargs['logfile']
     if log.name.endswith('-1.log'):
      event={'type':'turn.failed','error':{'message':'401 invalid_api_key https://api.openai.com/v1/responses'}};rc=1
     else: event={'type':'turn.completed'};rc=0
     log.write_text(json.dumps(event)+'\n');return types.SimpleNamespace(returncode=rc)
    return types.SimpleNamespace(returncode=0)
   with mock.patch.object(module,'command',side_effect=fake_command),mock.patch.object(module.subprocess,'run',return_value=types.SimpleNamespace(returncode=1)):
    result,selected=module.codex_connection_check(env,root,cache)
   self.assertIsNone(selected)
   self.assertEqual(env['CODEX_HOME'],'/original'); self.assertEqual(env['OPENAI_API_KEY'],'sk-or-v1-fake')
   self.assertEqual(result['CODEX_HOME'],str(cache/'codex官方登录'));self.assertNotIn('OPENAI_API_KEY',result);self.assertNotIn('CODEX_API_KEY',result);self.assertEqual(result['CUSTOM_SENTINEL'],'keep')
   self.assertEqual(sum('--skip-git-repo-check' in argv for argv,_ in calls),2);self.assertTrue(any(argv==['codex','login'] for argv,_ in calls))
 def test_unsupported_model_uses_catalog_and_pins_successful_model(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=pathlib.Path(tmp); cache=root/'cache';cache.mkdir(); calls=[]
   env={'PATH':'/bin','CODEX_HOME':'/auth'}
   def fake_command(argv,**kwargs):
    calls.append(argv); assert '--skip-git-repo-check' in argv
    if '--model' not in argv:
     event={'type':'turn.failed','error':{'message':"The 'gpt-5.3-codex' model is not supported when using Codex with a ChatGPT account. model_not_found"}};rc=1
    else:
     assert argv[argv.index('--model')+1]=='gpt-5.4';event={'type':'turn.completed'};rc=0
    kwargs['logfile'].write_text(json.dumps(event)+'\n');return types.SimpleNamespace(returncode=rc)
   with mock.patch.object(module,'command',side_effect=fake_command),mock.patch.object(module,'available_codex_models',return_value=['gpt-5.3-codex','gpt-5.4']):
    chosen_env,model=module.codex_connection_check(env,root,cache)
   self.assertEqual(chosen_env,env);self.assertEqual(model,'gpt-5.4');self.assertEqual(len(calls),2)
 def test_missing_model_catalog_installs_private_cli(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=pathlib.Path(tmp);cache=root/'cache';cache.mkdir();env={'PATH':'/bin','CODEX_HOME':'/existing'}; calls=[]
   def fake_command(argv,**kwargs):
    calls.append(argv)
    if argv[0]=='npm':
     executable(cache/'codex新版/node_modules/.bin/codex','#!/bin/sh\nexit 0\n');return types.SimpleNamespace(returncode=0)
    if len([x for x in calls if '--skip-git-repo-check' in x])==1:
     event={'type':'turn.failed','error':{'message':"model_not_found: The 'gpt-5.3-codex' model is not supported when using Codex"}};rc=1
    else: event={'type':'turn.completed'};rc=0
    kwargs['logfile'].write_text(json.dumps(event)+'\n');return types.SimpleNamespace(returncode=rc)
   with mock.patch.object(module,'command',side_effect=fake_command),mock.patch.object(module,'available_codex_models',return_value=[]):
    newenv,model=module.codex_connection_check(env,root,cache)
   self.assertIsNone(model);self.assertEqual(env['PATH'],'/bin');self.assertEqual(newenv['PATH'].split(os.pathsep)[0],str(cache/'codex新版/node_modules/.bin'));self.assertEqual(newenv['CODEX_HOME'],'/existing')
   self.assertEqual(sum(argv[0]=='npm' for argv in calls),1)
 def test_model_catalog_filters_hidden_and_disabled_entries(self):
  with tempfile.TemporaryDirectory() as tmp:
   base=pathlib.Path(tmp);bin_dir=base/'bin';bin_dir.mkdir()
   executable(bin_dir/'codex','''#!/usr/bin/env python3
import json,sys
for line in sys.stdin:
 q=json.loads(line)
 if q.get('method')=='initialize': print(json.dumps({'id':q['id'],'result':{}}),flush=True)
 if q.get('method')=='model/list':
  print(json.dumps({'id':q['id'],'result':{'data':[{'model':'gpt-old','isDefault':True,'hidden':True},{'model':'gpt-unsupported','multiAgentVersion':'disabled'},{'model':'gpt-5.4','isDefault':True},{'model':'gpt-codex','isDefault':False},{'model':'invalid model'}],'nextCursor':None}}),flush=True)
''')
   env=os.environ.copy();env['PATH']=str(bin_dir)+os.pathsep+env['PATH']
   self.assertEqual(module.available_codex_models(env,seconds=4),['gpt-5.4','gpt-codex'])
 def test_model_quota_error_stops_without_trying_or_upgrading(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=pathlib.Path(tmp);cache=root/'cache';cache.mkdir();calls=[]
   def fake_command(argv,**kwargs):
    calls.append(argv)
    if len(calls)==1:msg="model_not_found: The 'gpt-5.3-codex' model is not supported when using Codex"
    else:msg='429 usage limit reached for this account'
    kwargs['logfile'].write_text(json.dumps({'type':'turn.failed','error':{'message':msg}})+'\n');return types.SimpleNamespace(returncode=1)
   with mock.patch.object(module,'command',side_effect=fake_command),mock.patch.object(module,'available_codex_models',return_value=['gpt-5.4','gpt-5.5']):
    with self.assertRaises(module.SetupError) as error:module.codex_connection_check({'PATH':'/bin'},root,cache)
   self.assertIn('429 usage limit',str(error.exception));self.assertEqual(len(calls),2);self.assertFalse(any(x[0]=='npm' for x in calls))
 def test_non_auth_connection_error_does_not_force_login(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=pathlib.Path(tmp);cache=root/'cache';cache.mkdir()
   def fake_command(argv,**kwargs):
    kwargs['logfile'].write_text(json.dumps({'type':'turn.failed','error':{'message':'Proxy HTTP 403'}})+'\n');return types.SimpleNamespace(returncode=1)
   with mock.patch.object(module,'command',side_effect=fake_command),mock.patch.object(module.subprocess,'run') as status:
    with self.assertRaises(module.SetupError) as exc:module.codex_connection_check({'PATH':'/bin'},root,cache)
   self.assertIn('Proxy HTTP 403',str(exc.exception));status.assert_not_called()
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
   executable(sdk/'emulator/emulator','#!/usr/bin/python3\nimport os,pathlib,time\n(pathlib.Path(os.environ["ANDROID_AVD_HOME"])/"emulator-started").touch()\ntime.sleep(100)\n')
   executable(sdk/'cmdline-tools/latest/bin/sdkmanager','#!/bin/sh\nexit 0\n')
   executable(sdk/'cmdline-tools/latest/bin/avdmanager','#!/bin/sh\nexit 0\n')
   executable(sdk/'platform-tools/adb',"#!/bin/sh\ncase \"$*\" in *getprop*) echo 1;; *instrument*) echo 'OK (3 tests)';; *) echo Success;; esac\n")
   executable(bindir/'git',f'''#!/usr/bin/env python3
import pathlib,sys
args=sys.argv[1:]
if 'clone' in args:
 p=pathlib.Path(args[-1]);p.mkdir(parents=True)
 if 'nowinandroid.git' in args[-2]:
  g=p/'gradlew';g.write_text("#!/bin/sh\\ntest ! -e $ANDROID_AVD_HOME/emulator-started || exit 91\\nmkdir -p app/build/outputs/apk/demo/debug app/build/outputs/apk/androidTest/demo/debug\\ntouch app/build/outputs/apk/demo/debug/app.apk app/build/outputs/apk/androidTest/demo/debug/test.apk\\n");g.chmod(0o755)
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
if len(sys.argv)>1 and sys.argv[1]=='app-server':
 for line in sys.stdin:
  req=json.loads(line)
  if req.get('method')=='initialize': print(json.dumps({'id':req['id'],'result':{}}),flush=True)
  if req.get('method')=='model/list':
   print(json.dumps({'id':req['id'],'result':{'data':[{'model':'gpt-5.3-codex','isDefault':True},{'model':'gpt-5.4','isDefault':False}],'nextCursor':None}}),flush=True)
 sys.exit(0)
if '--skip-git-repo-check' in sys.argv:
 if '--model' not in sys.argv: print(json.dumps({'type':'turn.failed','error':{'message':"model_not_found: The 'gpt-5.3-codex' model is not supported when using Codex"}}));sys.exit(1)
 assert sys.argv[sys.argv.index('--model')+1]=='gpt-5.4'; print(json.dumps({'type':'turn.completed'}));sys.exit(0)
assert '--model' in sys.argv and sys.argv[sys.argv.index('--model')+1]=='gpt-5.4'
assert any('mcp_servers.mobile-mcp.command=' in arg for arg in sys.argv)
assert 'sandbox_workspace_write.network_access=true' in sys.argv
assert pathlib.Path(os.environ['ANDROID_EXPERIMENT_MCP_COMMAND']).resolve().is_relative_to(pathlib.Path(os.environ['HOME'])/'codex-agent-experiments/工具缓存')
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
   original=module.command; installs=[]
   def wrapped(argv,**kwargs):
    if len(argv)>=3 and argv[1:3]==['-m','venv']:
     installs.append('venv');pathlib.Path(argv[3]).symlink_to(pathlib.Path(sys.executable).parent.parent,target_is_directory=True); return
    if len(argv)>=4 and argv[1:4]==['-m','pip','install']: installs.append('pip');return
    if argv[0]=='npm' and '@mobilenext/mobile-mcp@1.0.17' in argv:
     installs.append('mcp');prefix=pathlib.Path(argv[argv.index('--prefix')+1]);modules=prefix/'node_modules';dest=modules/'.bin/mcp-server-mobile';executable(dest,'#!/bin/sh\nexit 0\n')
     package=modules/'@mobilenext/mobile-mcp';package.mkdir(parents=True);(package/'package.json').write_text(json.dumps({'version':'1.0.17'}))
     node=subprocess.run(['node','-p',"process.platform+'-'+process.arch"],env=kwargs['env'],capture_output=True,text=True);arch=node.stdout.strip().replace('-x64','-amd64');executable(modules/'@mobilenext'/('mobilecli-'+arch)/('mobilecli-'+arch),'#!/bin/sh\nexit 0\n');return
    return original(argv,**kwargs)
   env={'HOME':str(home),'ANDROID_HOME':str(sdk),'ANDROID_SDK_ROOT':str(sdk),'CODEX_HOME':str(base/'codexhome'),'PATH':str(bindir)+os.pathsep+os.environ['PATH']}
   with mock.patch.dict(os.environ,env,clear=False),mock.patch.object(module,'command',side_effect=wrapped),mock.patch.object(module,'python_env_valid',side_effect=lambda p:p.is_file()),mock.patch.object(module.os,'uname',return_value=type('U',(),{'machine':'x86_64'})()):
    self.assertEqual(module.main(),0)
    self.assertEqual(module.main(),0)
   experiment_base=home/'codex-agent-experiments';runs=sorted(experiment_base.glob('android01-*'))
   self.assertEqual(len(runs),2);self.assertEqual(installs.count('venv'),1);self.assertEqual(installs.count('pip'),1);self.assertEqual(installs.count('mcp'),1)
   for run in runs:
    self.assertTrue((run/'实验报告.html').is_file());self.assertFalse((run/'工具环境').exists());self.assertFalse((run/'设备工具').exists());self.assertFalse((run/'Gradle缓存').exists())
   shutil.rmtree(runs[0]);self.assertTrue((experiment_base/'工具缓存/Gradle缓存').is_dir());self.assertTrue((runs[1]/'实验报告.html').is_file())
   out=runs[1]; info=json.loads((out/'实验状态.json').read_text());
   self.assertEqual(info['model_selection'],'gpt-5.4')
   self.assertIn('formal_elapsed_seconds',info); self.assertNotIn('phases',info)
   self.assertIn('正式开发耗时',(out/'实验报告.html').read_text())
   self.assertNotIn('检查工具与登录',(out/'实验报告.html').read_text())
   self.assertEqual(info['session_count'],3); self.assertEqual(info['recognized_messages'],2); self.assertEqual(info['telemetry_events_matched'],1)
   self.assertEqual([d['baseline_tests'] for d in info['devices']],[3,3]); self.assertTrue((out/'实验报告.html').exists())
   self.assertIn('30.000 ms',(out/'实验报告.html').read_text())

if __name__=='__main__': unittest.main(verbosity=2)
