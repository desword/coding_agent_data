import csv, importlib.util, json, pathlib, tempfile, unittest
P=pathlib.Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('agent_experiment',P/'agent_experiment.py'); a=importlib.util.module_from_spec(spec); spec.loader.exec_module(a)

def write(p, records): p.write_text(''.join(json.dumps(x,ensure_ascii=False)+'\n' for x in records),encoding='utf-8')
def line(typ,payload): return {'timestamp':'2026-11-16T10:00:00Z','type':typ,'payload':payload}
class OfflineTests(unittest.TestCase):
 def test_extract_and_generate(self):
  with tempfile.TemporaryDirectory() as t:
   root=pathlib.Path(t); p=root/'parent.jsonl'; q=root/'child.jsonl'
   write(p,[line('session_meta',{'id':'root'}),line('response_item',{'type':'function_call','name':'spawn_agent','arguments':json.dumps({'task_name':'/root/a','message':'请分析登录'},ensure_ascii=False),'call_id':'one'}),line('response_item',{'type':'function_call_output','call_id':'one','output':'{"task_name":"/root/a"}'}),line('response_item',{'type':'function_call','name':'wait_agent','arguments':'{}','call_id':'two'}),line('response_item',{'type':'function_call_output','call_id':'two','output':json.dumps({'status':{'child':{'completed':'发现问题'}}},ensure_ascii=False)}),line('event_msg',{'type':'agent_message','message':'重复内容不统计'})])
   write(q,[line('session_meta',{'id':'child','source':{'subagent':{'thread_spawn':{'parent_thread_id':'root','agent_path':'/root/a'}}}}),line('event_msg',{'type':'task_complete','last_agent_message':'发现问题'})])
   sessions=[a.meta(p),a.meta(q)]; rows,diag=a.parse_sessions(sessions,'root')
   self.assertEqual(len(rows),2); self.assertEqual(sum(x['UTF8字节'] for x in rows),len('请分析登录'.encode())+len('发现问题'.encode()))
   self.assertEqual(rows[1]['发送方'],'/root/a')
   a.analyze(root,{'run_id':'fixture','root_thread_id':'root','session_count':2,'session_note':'synthetic','exit_code':0},sessions)
   self.assertTrue((root/'实验统计报告.docx').exists())
   with (root/'消息明细.csv').open(encoding='utf-8-sig') as f: self.assertEqual(len(list(csv.DictReader(f))),2)
 def test_unmatched_parent_not_counted(self):
  with tempfile.TemporaryDirectory() as t:
   root=pathlib.Path(t); home=root/'home'; sessions=home/'sessions'; sessions.mkdir(parents=True); out=root/'out';out.mkdir()
   write(sessions/'r.jsonl',[line('session_meta',{'id':'root'})]); write(sessions/'a.jsonl',[line('session_meta',{'id':'a','source':{'subagent':{'thread_spawn':{'parent_thread_id':'other'}}}})])
   found,_=a.collect_sessions(home,out,'root',0); self.assertEqual([x['id'] for x in found],['root'])
 def test_empty_and_unknown(self):
  with tempfile.TemporaryDirectory() as t:
   root=pathlib.Path(t); p=root/'r.jsonl'
   write(p,[line('session_meta',{'id':'root'}),line('response_item',{'type':'function_call','name':'spawn_agent','arguments':'{}','call_id':'1'})])
   rows,diag=a.parse_sessions([a.meta(p)],'root'); self.assertEqual(rows,[]); self.assertEqual(len(diag),1)
 def test_latency_pairs_and_incomplete_calls(self):
  with tempfile.TemporaryDirectory() as t:
   p=pathlib.Path(t)/'r.jsonl'
   def event(timestamp,payload): return {'timestamp':timestamp,'type':'response_item','payload':payload}
   write(p,[line('session_meta',{'id':'root'}),
    event('2026-01-01T00:00:00Z',{'type':'function_call','name':'wait_agent','call_id':'a'}),
    event('2026-01-01T00:00:01.250Z',{'type':'function_call_output','call_id':'a','output':'{}'}),
    event('2026-01-01T00:00:00Z',{'type':'function_call','name':'send_message','call_id':'b'}),
    event('',{'type':'function_call_output','call_id':'b','output':'{}'}),
    event('2026-01-01T00:00:00Z',{'type':'function_call','name':'spawn_agent','call_id':'c'})])
   rows=a.parse_latencies([a.meta(p)])
   self.assertEqual([(r['measurement_status'],r['duration_ms']) for r in rows],[('ok',1250.0),('invalid_timestamp',''),('missing_output','')])
if __name__=='__main__': unittest.main()
