import json, os, pathlib, subprocess, sys, tempfile, unittest
KIT=pathlib.Path(__file__).resolve().parents[1]
FAKE='''#!/usr/bin/env python3
import json,os,pathlib,sys
if '--version' in sys.argv: print('codex-cli fixture'); raise SystemExit
p=pathlib.Path(os.environ['CODEX_HOME'])/'sessions'/'2026'/'11'/'16';p.mkdir(parents=True)
def row(t,x): return {'timestamp':'2026-11-16T10:00:00Z','type':t,'payload':x}
def write(f,arr): f.write_text(''.join(json.dumps(x,ensure_ascii=False)+'\\n' for x in arr),encoding='utf-8')
write(p/'root.jsonl',[row('session_meta',{'id':'root'}),row('response_item',{'type':'function_call','name':'spawn_agent','arguments':json.dumps({'task_name':'/root/a','message':'检查模块'},ensure_ascii=False),'call_id':'c1'}),row('response_item',{'type':'function_call','name':'wait_agent','arguments':'{}','call_id':'c2'}),row('response_item',{'type':'function_call_output','call_id':'c2','output':json.dumps({'status':{'child':{'completed':'检查完毕'}}},ensure_ascii=False)})])
write(p/'child.jsonl',[row('session_meta',{'id':'child','source':{'subagent':{'thread_spawn':{'parent_thread_id':'root','agent_path':'/root/a'}}}})])
write(p/'unrelated.jsonl',[row('session_meta',{'id':'other'})])
print(json.dumps({'type':'thread.started','thread_id':'root'}))
'''
class RunnerTest(unittest.TestCase):
 def test_end_to_end(self):
  with tempfile.TemporaryDirectory() as x:
   tmp=pathlib.Path(x); bin=tmp/'bin';bin.mkdir(); fake=bin/'codex'; fake.write_text(FAKE,encoding='utf-8');fake.chmod(0o755)
   repo=tmp/'repo';repo.mkdir();subprocess.run(['git','init','-q',str(repo)],check=True)
   env=os.environ.copy();env['PATH']=str(bin)+os.pathsep+env['PATH'];env['CODEX_HOME']=str(tmp/'home')
   out=tmp/'run'; cmd=[sys.executable,str(KIT/'agent_experiment.py'),'--project',str(repo),'--output',str(out),'--timeout','10']
   p=subprocess.run(cmd,env=env,capture_output=True,text=True); self.assertEqual(p.returncode,0,p.stderr)
   meta=json.loads((out/'实验信息.json').read_text());self.assertEqual(meta['session_count'],2);self.assertEqual(meta['recognized_messages'],2)
   self.assertTrue((out/'实验统计报告.docx').exists());self.assertTrue((out/'进程资源.csv').exists())
   self.assertEqual(len(list((out/'sessions').glob('*.jsonl'))),2)
   p=subprocess.run([sys.executable,str(KIT/'agent_experiment.py'),'--analyze',str(out)],env=env,capture_output=True,text=True);self.assertEqual(p.returncode,0,p.stderr)
if __name__=='__main__':unittest.main()
