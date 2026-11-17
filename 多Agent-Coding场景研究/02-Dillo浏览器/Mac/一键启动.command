#!/bin/sh
''':'
# Finder does not necessarily inherit Homebrew's PATH.
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export PATH
if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import sys; assert sys.version_info >= (3, 9)' >/dev/null 2>&1; then
  echo '正在准备 macOS 开发工具和 Python 3，请在系统窗口中确认安装。'
  if [ "$(uname -s)" = Darwin ] && command -v xcode-select >/dev/null 2>&1; then
    xcode-select --install 2>/dev/null || true
    n=0
    while [ "$n" -lt 120 ]; do
      sleep 15
      if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys; assert sys.version_info >= (3, 9)' >/dev/null 2>&1; then break; fi
      n=$((n+1)); echo "等待系统开发工具安装，已等待 $((n*15)) 秒。"
    done
  fi
fi
if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import sys; assert sys.version_info >= (3, 9)' >/dev/null 2>&1; then
  echo '未找到 Python 3.9+；请完成 macOS 开发工具安装后重新双击。'
  [ -t 0 ] && read -r ignored
  exit 1
fi
exec python3 "$0" "$@"
':'''
from __future__ import annotations
import argparse, collections, contextlib, csv, datetime as dt, fcntl, html, http.server, json, math, os, pathlib, platform, re, secrets, selectors, shlex, shutil, signal, socket, statistics, subprocess, sys, tarfile, tempfile, threading, time, urllib.error, urllib.request

APP_URL='https://github.com/dillo-browser/dillo.git'
APP_REV='6856c5016de8cc15d077ec8d785bac1a38b4a813'
ROLES=('W1','W2','W3','W4','W5')
TOPICS=('download/contract','download/parser','download/security','download/integration','download/tests')
WRITE_PATHS={'W1':('src/misc.h','dlib/'),'W2':('test/unit/disposition.c',),'W3':('test/unit/disposition_security.c',),'W4':('test/unit/disposition_http_test.py',),'leader':('src/misc.h','dlib/','test/unit/disposition.c','test/unit/disposition_security.c','test/unit/disposition_http_test.py')}
TIMEOUT=7200
MAX_MESSAGE=262144

class ExperimentError(Exception): pass

def stamp(): return dt.datetime.now(dt.timezone.utc).isoformat(timespec='milliseconds')
def clock(s):
    s=max(0,int(s)); return '%02d:%02d:%02d'%(s//3600,(s//60)%60,s%60)
def emit(s): print(s,flush=True)
def redacted(s):
    s=re.sub(r'(?i)(bearer\s+)[^\s,;"\']+',r'\1[隐藏]',str(s))
    s=re.sub(r'(?i)\b(api[_-]?key|access[_-]?token|refresh[_-]?token|token|authorization|password|secret)\b(\s*[=:]\s*["\']?)[^\s,;"\']+',r'\1\2[隐藏]',s)
    s=re.sub(r'\bsk-[A-Za-z0-9_*-]{4,}','[隐藏]',s)
    return s[-1800:]
def mkdir(p): p.mkdir(parents=True,exist_ok=True); return p

def system_snapshot():
    """Best-effort host memory counters; empty values mean unavailable."""
    result={'utc':stamp(),'mono_ns':time.monotonic_ns(),'swap_usage':'','vm_stat':''}
    if sys.platform=='darwin':
        for key,cmd in (('swap_usage',['sysctl','-n','vm.swapusage']),('vm_stat',['vm_stat'])):
            try:
                p=subprocess.run(cmd,capture_output=True,text=True,timeout=5)
                if p.returncode==0:result[key]=p.stdout.strip()
            except (OSError,subprocess.SubprocessError):pass
    return result

def host_profile():
    result={'system':platform.system(),'release':platform.release(),'machine':platform.machine(),'logical_cpus':os.cpu_count(),'physical_cpus':None,'memory_bytes':None}
    if sys.platform=='darwin':
        for key,name in (('physical_cpus','hw.physicalcpu'),('memory_bytes','hw.memsize')):
            try:
                p=subprocess.run(['sysctl','-n',name],capture_output=True,text=True,timeout=5)
                if p.returncode==0:result[key]=int(p.stdout.strip())
            except (OSError,ValueError,subprocess.SubprocessError):pass
    return result

@contextlib.contextmanager
def heartbeat(message):
    stop=threading.Event();started=time.monotonic()
    def tick():
        while not stop.wait(15):emit(f'[状态] {message}，已耗时 {clock(time.monotonic()-started)}；等待连接或数据。')
    thread=threading.Thread(target=tick,daemon=True);thread.start()
    try:yield
    finally:stop.set();thread.join(timeout=2)

def write_json(path,obj):
    tmp=path.with_name(path.name+'.tmp')
    tmp.write_text(json.dumps(obj,ensure_ascii=False,indent=2),encoding='utf-8')
    os.replace(tmp,path)

def write_csv(path,fields,rows):
    with path.open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields,extrasaction='ignore');w.writeheader()
        for row in rows:
            w.writerow({k:("'"+v if isinstance(v,str) and v.lstrip().startswith(('=','+','-','@')) else v) for k,v in row.items()})

def stop_group(p):
    if not p or p.poll() is not None: return
    for sig,wait in ((signal.SIGINT,3),(signal.SIGTERM,4),(signal.SIGKILL,2)):
        try: os.killpg(p.pid,sig)
        except ProcessLookupError: return
        try: p.wait(timeout=wait); return
        except subprocess.TimeoutExpired: pass

def run(argv,*,cwd=None,env=None,log=None,timeout=600,allow_fail=False):
    emit('\n$ '+' '.join(shlex.quote(str(x)) for x in argv)); begin=time.monotonic()
    with (open(log,'a',encoding='utf-8') if log else open(os.devnull,'w')) as out:
        p=subprocess.Popen([str(a) for a in argv],cwd=cwd,env=env,stdout=out,stderr=subprocess.STDOUT,start_new_session=True)
        last=begin
        try:
            while p.poll() is None:
                time.sleep(.25); now=time.monotonic()
                if now-begin>timeout:
                    stop_group(p); raise ExperimentError(f'命令超时：{argv[0]}，完整日志：{log}')
                if now-last>=15:
                    size=pathlib.Path(log).stat().st_size if log and pathlib.Path(log).exists() else 0
                    emit(f'[状态] {pathlib.Path(str(argv[0])).name} 运行中，已耗时 {clock(now-begin)}；日志 {size:,} 字节。')
                    if log and size:
                        with open(log,'rb') as progress:
                            progress.seek(max(0,size-4096));lines=progress.read().decode('utf-8',errors='replace').splitlines()
                        if lines:emit('[最近输出] '+redacted(lines[-1])[-250:])
                    last=now
            code=p.returncode
        except BaseException:
            stop_group(p); raise
    if code and not allow_fail:
        detail=''
        if log and pathlib.Path(log).exists(): detail=redacted(pathlib.Path(log).read_text(encoding='utf-8',errors='replace')[-3000:])
        raise ExperimentError(f'{argv[0]} 返回 {code}：{detail}；完整日志：{log}')
    return code

@contextlib.contextmanager
def cache_lock(cache):
    mkdir(cache)
    with (cache/'dillo-codex.lock').open('a+') as f:
        started=time.monotonic();notice=started
        while True:
            try:fcntl.flock(f.fileno(),fcntl.LOCK_EX|fcntl.LOCK_NB);break
            except BlockingIOError:
                now=time.monotonic()
                if now-started>900:raise ExperimentError('等待公共缓存超时；请检查是否有其他实验仍在准备。')
                if now-notice>=15:emit('[缓存] 等待其他实验释放公共缓存，已等待 '+clock(now-started));notice=now
                time.sleep(.5)
        try: yield
        finally: fcntl.flock(f.fileno(),fcntl.LOCK_UN)

def usable_codex(binary):
    try:
        p=subprocess.run([str(binary),'--help'],capture_output=True,text=True,timeout=25)
        return p.returncode==0 and '--no-daemon' in p.stdout
    except (OSError,subprocess.SubprocessError): return False

def ensure_codex(cache,env,log):
    system=shutil.which('codex',path=env.get('PATH'))
    if system and usable_codex(system): emit('[工具] 使用现有 Codex：'+system); return system
    target=cache/'codex独立版'/'codex'
    with cache_lock(cache):
        if target.exists() and usable_codex(target): emit('[缓存] 复用 Codex。'); return str(target)
        if sys.platform!='darwin': raise ExperimentError('需要支持 --no-daemon 的 Codex CLI；本机自动下载仅支持 macOS。')
        machine=os.uname().machine.lower()
        arch={'arm64':'aarch64','aarch64':'aarch64','x86_64':'x86_64'}.get(machine)
        if not arch: raise ExperimentError('不支持的 Mac 处理器：'+machine)
        asset=f'codex-{arch}-apple-darwin.tar.gz'
        url='https://github.com/openai/codex/releases/latest/download/'+asset
        emit('[工具] 正在从 Codex 官方 GitHub Releases 下载 '+asset)
        mkdir(target.parent)
        with tempfile.TemporaryDirectory(dir=target.parent,prefix='.download-') as td:
            archive=pathlib.Path(td)/asset
            for attempt in range(1,4):
                try:
                    req=urllib.request.Request(url,headers={'User-Agent':'Dillo-Codex-Experiment'})
                    with heartbeat('正在下载 Codex'),urllib.request.urlopen(req,timeout=60) as resp, archive.open('wb') as f:
                        total=0; last=time.monotonic()
                        while True:
                            part=resp.read(1024*1024)
                            if not part: break
                            total+=len(part)
                            if total>300*1024*1024: raise ExperimentError('Codex 下载超过预期大小。')
                            f.write(part)
                            if time.monotonic()-last>=10: emit(f'[下载] Codex 已下载 {total/1024/1024:.1f} MiB。');last=time.monotonic()
                    break
                except (OSError,urllib.error.URLError) as exc:
                    emit(f'[下载] 第 {attempt} 次失败：{redacted(exc)}')
                    if attempt==3: raise ExperimentError('Codex 自动下载失败，请检查网络后重新运行。')
                    time.sleep(attempt*2)
            with tarfile.open(archive,'r:gz') as tf:
                choices=[m for m in tf.getmembers() if m.isfile() and pathlib.PurePosixPath(m.name).name==f'codex-{arch}-apple-darwin']
                if len(choices)!=1 or choices[0].size>300*1024*1024: raise ExperimentError('Codex 官方压缩包格式异常。')
                stage=pathlib.Path(td)/'codex'
                with tf.extractfile(choices[0]) as src, stage.open('wb') as dest: shutil.copyfileobj(src,dest)
                stage.chmod(0o755)
                if not usable_codex(stage): raise ExperimentError('下载的 Codex 无法执行或不支持独立进程。')
                os.replace(stage,target)
        return str(target)

def model_error(path):
    errors=[]
    if path.exists():
        for line in path.read_text(encoding='utf-8',errors='replace').splitlines():
            try: event=json.loads(line)
            except ValueError: continue
            if not isinstance(event,dict): continue
            item=event.get('item');item=item if isinstance(item,dict) else {}
            if event.get('type') in ('turn.failed','error','item.failed') or item.get('type')=='error':
                detail=event.get('error') or event.get('message') or item.get('message') or item or ''
                errors.append(redacted(detail))
    return ' | '.join(errors[-3:])

def available_models(codex):
    process=None; selector=None
    try:
        process=subprocess.Popen([codex,'app-server'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,start_new_session=True)
        for q in ({'id':1,'method':'initialize','params':{'clientInfo':{'name':'dillo-codex-experiment','version':'1.0'}}},{'method':'initialized','params':{}},{'id':2,'method':'model/list','params':{'limit':100}}):
            process.stdin.write((json.dumps(q)+'\n').encode())
        process.stdin.flush();selector=selectors.DefaultSelector();selector.register(process.stdout,selectors.EVENT_READ)
        end=time.monotonic()+25;buf=b''
        while time.monotonic()<end and process.poll() is None:
            for key,_ in selector.select(.5):
                chunk=os.read(key.fd,65536)
                if not chunk:continue
                buf+=chunk
                if len(buf)>4*1024*1024:return []
                while b'\n' in buf:
                    line,buf=buf.split(b'\n',1)
                    try:reply=json.loads(line)
                    except (ValueError,UnicodeError):continue
                    if not isinstance(reply,dict):continue
                    if reply.get('id')!=2:continue
                    data=reply.get('result',{}).get('data',[]);found=[]
                    for item in data:
                        if not isinstance(item,dict) or item.get('hidden') is True:continue
                        name=item.get('model') or item.get('id')
                        if isinstance(name,str) and re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.:/-]{0,119}',name):found.append((not bool(item.get('isDefault')),name))
                    return [name for _,name in sorted(found)]
    except (OSError,ValueError,subprocess.SubprocessError):pass
    finally:
        if selector:selector.close()
        if process:
            stop_group(process)
            if process.stdin:process.stdin.close()
            if process.stdout:process.stdout.close()
    return []

def check_auth(codex,app,logs):
    p=subprocess.run([codex,'login','status'],capture_output=True,text=True,timeout=30)
    if p.returncode:
        emit('[登录] 将启动 Codex 官方登录，请在浏览器或终端完成认证。')
        result=subprocess.run([codex,'login'])
        if result.returncode: raise ExperimentError('Codex 官方登录未完成，请重新双击并完成认证。')
    def probe(model,index):
        emit('[登录] 正在检查 '+(model or 'Codex 默认模型')+'；该步骤不计入正式开发耗时。')
        path=logs/f'模型检查-{index}.jsonl';err=logs/f'模型检查-{index}.log'
        args=[codex,'--no-daemon','-a','never','exec','--json','--sandbox','read-only','-C',str(app)]
        if model:args.extend(['--model',model])
        args.append('只回复 OK。')
        with path.open('w',encoding='utf-8') as f,err.open('w',encoding='utf-8') as e:
            p=subprocess.Popen(args,stdin=subprocess.DEVNULL,stdout=f,stderr=e,start_new_session=True)
            t=time.monotonic();notice=t
            while p.poll() is None:
                time.sleep(.5);now=time.monotonic()
                if now-t>180:
                    stop_group(p);detail=model_error(path) or redacted(err.read_text(encoding='utf-8',errors='replace')[-1000:])
                    raise ExperimentError('Codex 模型连接检查超时：'+(detail or '请查看记录/模型检查日志。'))
                if now-notice>15:
                    detail=model_error(path)
                    emit('[登录] 正在检查模型连接，已耗时 '+clock(now-t)+(('；最近提示：'+detail[-300:]) if detail else ''));notice=now
        kinds=[]
        for line in path.read_text(encoding='utf-8',errors='replace').splitlines():
            try:kinds.append(json.loads(line).get('type'))
            except ValueError:pass
        message=model_error(path) or redacted(err.read_text(encoding='utf-8',errors='replace'))
        return p.returncode==0 and 'turn.completed' in kinds,message
    ok,message=probe(None,1)
    if ok:emit('[登录] 默认模型连接成功。');return None
    text=message.lower()
    if 'model_not_found' not in text and not ('model' in text and ('not supported' in text or 'not available' in text)):
        raise ExperimentError('Codex 模型连接失败：'+message)
    emit('[模型] 默认模型不可用，正在从 Codex 获取可选模型并逐个验证。')
    for index,model in enumerate(available_models(codex)[:4],2):
        ok,message=probe(model,index)
        if ok:emit('[模型] 使用已验证模型 '+model);return model
        if 'model_not_found' not in message.lower() and 'not supported' not in message.lower() and 'not available' not in message.lower():break
    raise ExperimentError('Codex 可选模型验证未通过：'+message)

def prepare_repos(cache,root,log):
    bare=cache/'dillo-6856c501.git'
    with cache_lock(cache):
        if not (bare/'HEAD').exists(): run(['git','init','--bare',bare],log=log,timeout=60)
        ok=subprocess.run(['git','--git-dir',str(bare),'cat-file','-e',APP_REV+'^{commit}'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0
        if not ok:
            for n in range(1,4):
                rc=run(['git','--git-dir',bare,'fetch','--depth','1',APP_URL,APP_REV],log=log,timeout=600,allow_fail=True)
                if not rc: break
                if n==3: raise ExperimentError('Dillo 下载失败，请查看准备过程.log；再次运行会重用已下载的内容。')
                emit(f'[下载] Dillo 第 {n} 次失败，准备重试。');time.sleep(n*2)
        else: emit('[缓存] 复用 Dillo 固定版本。')
        # A commit fetched by hash lives only in FETCH_HEAD; advertise a real ref
        # so local clones of the shallow cache actually receive that commit.
        run(['git','--git-dir',bare,'update-ref','refs/heads/experiment-baseline',APP_REV],log=log,timeout=30)
        run(['git','--git-dir',bare,'symbolic-ref','HEAD','refs/heads/experiment-baseline'],log=log,timeout=30)
    repos={}
    for role in ('leader',)+ROLES:
        dst=root/('应用' if role=='leader' else 'workers/'+role)
        mkdir(dst.parent)
        run(['git','clone','--quiet','--no-checkout','--local',bare,dst],log=log,timeout=180)
        run(['git','checkout','--quiet','-b','experiment/'+role,APP_REV],cwd=dst,log=log,timeout=90)
        run(['git','config','user.name','Codex Experiment'],cwd=dst,log=log,timeout=30)
        run(['git','config','user.email','codex-experiment@localhost'],cwd=dst,log=log,timeout=30)
        build=mkdir(dst/'.experiment-build');(build/'config.h').write_text('#define HAVE_STDINT_H 1\n',encoding='utf-8')
        # Keep generated files out of agent commits without changing tracked project files.
        with (dst/'.git/info/exclude').open('a',encoding='utf-8') as f:f.write('\n/.experiment-build/\n')
        repos[role]=dst
    return repos

def baseline(repo,cc,log):
    exe=repo/'.experiment-build/disposition-baseline'
    run([cc,'-std=gnu11','-I'+str(repo/'.experiment-build'),'-I.', 'test/unit/disposition.c','dlib/dlib.c','-o',exe],cwd=repo,log=log,timeout=120)
    run([exe],cwd=repo,log=log,timeout=120)
    source=(repo/'test/unit/disposition.c').read_text(encoding='utf-8')
    part=source[source.index('struct testcase cases[]'):source.index('static int equal')]
    n=len(re.findall(r'^\s*\{',part,re.M))
    if n<1: raise ExperimentError('上游测试未发现测试条目，不能将空测试视为成功。')
    emit(f'[基线] Dillo Content-Disposition 的 {n} 条上游用例通过。')
    return n

class State:
    def __init__(self,root,repos,codex,env,control,cc):
        self.root=root;self.repos=repos;self.codex=codex;self.env=env;self.control=control;self.cc=cc;self.model=None
        self.lock=threading.RLock();self.changed=threading.Condition(self.lock);self.git_lock=threading.Lock()
        self.queues={r:collections.deque() for r in ('leader',)+ROLES}
        self.subs={r:set() for r in ROLES};self.messages={};self.events=[];self.procs={};self.runs={};self.tool_times=[];self.token_usage=[];self.sample_rows=[];self.system_rows=[]
        self.start_ns=0;self.end_ns=0;self.stop=threading.Event();self.agent_tools={};self.watchers=[];self.metrics_endpoints={};self.telemetry_enabled=False
        self.raw=mkdir(root/'记录');self.eventfile=(self.raw/'路由事件.jsonl').open('a',encoding='utf-8')
    def record(self,event):
        with self.lock:
            event={'utc':stamp(),'mono_ns':time.monotonic_ns(),**event};self.events.append(event)
            if not self.eventfile.closed:self.eventfile.write(json.dumps(event,ensure_ascii=False)+'\n');self.eventfile.flush()
            return event
    def deliver(self,sender,recipients,text,topic='',kind='message',client_send_ns=None):
        if not isinstance(text,str) or not text.strip():raise ValueError('消息正文不能为空。')
        if len(text.encode('utf-8'))>MAX_MESSAGE:raise ValueError('消息正文超过 256 KiB。')
        if sender not in self.queues:raise ValueError('未知发送方。')
        if sender!='leader' and recipients!=['leader']:raise ValueError('Worker 消息须发给 Leader。')
        if not recipients or any(r not in self.queues or r==sender for r in recipients):raise ValueError('未知或无效接收方。')
        recv_ns=time.monotonic_ns(); uid=secrets.token_hex(8)
        payload=text.encode('utf-8')
        with self.changed:
            self.messages[uid]={'id':uid,'sender':sender,'recipients':recipients,'text':text,'topic':topic,'kind':kind,'body_bytes':len(payload),'client_send_ns':client_send_ns,'service_recv_ns':recv_ns,'deliveries':{}}
            for recipient in recipients:
                enq=time.monotonic_ns();self.queues[recipient].append(uid);self.messages[uid]['deliveries'][recipient]={'enqueued_ns':enq}
                self.record({'event':'enqueue','id':uid,'sender':sender,'receiver':recipient,'topic':topic,'kind':kind,'body_bytes':len(payload),'service_recv_ns':recv_ns,'client_send_ns':client_send_ns,'enqueued_ns':enq,'text':text})
            self.changed.notify_all()
        emit(f'[通信] {sender} → {",".join(recipients)}，{len(payload)} 字节'+(f'，主题 {topic}' if topic else ''))
        return uid
    def poll(self,role,seconds):
        if role not in self.queues:raise ValueError('未知 Agent。')
        deadline=time.monotonic()+min(max(float(seconds),0),15)
        with self.changed:
            while not self.queues[role] and not self.stop.is_set() and time.monotonic()<deadline:self.changed.wait(deadline-time.monotonic())
            result=[]
            while self.queues[role] and len(result)<100:
                uid=self.queues[role].popleft();m=self.messages[uid];n=time.monotonic_ns();m['deliveries'][role]['dequeue_ns']=n
                self.record({'event':'dequeue','id':uid,'sender':m['sender'],'receiver':role,'dequeue_ns':n})
                result.append({k:m[k] for k in ('id','sender','text','topic','kind')})
            return result
    def ack(self,role,uid,client_receive_ns):
        with self.lock:
            m=self.messages.get(uid);d=m and m['deliveries'].get(role)
            if not d or 'dequeue_ns' not in d:raise ValueError('无法确认未知投递。')
            if 'client_receive_ns' not in d:
                d['client_receive_ns']=client_receive_ns;self.record({'event':'receive_ack','id':uid,'sender':m['sender'],'receiver':role,'client_receive_ns':client_receive_ns})
    def subscribe(self,role,topic):
        if role not in ROLES or topic not in TOPICS:raise ValueError('未知 Agent 或 Topic。')
        with self.lock:self.subs[role].add(topic);self.record({'event':'subscribe','agent':role,'topic':topic})
    def unsubscribe(self,role,topic,origin='agent'):
        if role not in ROLES or topic not in TOPICS:raise ValueError('未知 Agent 或 Topic。')
        with self.lock:self.subs[role].discard(topic);self.record({'event':'unsubscribe','agent':role,'topic':topic,'origin':origin})
    def git(self,role,operation,args,allow_fail=False):
        started=time.monotonic_ns()
        try:
            env=self.env.copy();env['GIT_TERMINAL_PROMPT']='0';env['GIT_EDITOR']='true'
            result=subprocess.run(['git',*map(str,args)],cwd=self.repos[role],env=env,capture_output=True,text=True,timeout=120)
            detail=redacted((result.stdout+'\n'+result.stderr).strip())
            with self.lock:
                with (self.raw/'Git操作.log').open('a',encoding='utf-8') as f:f.write(f'{stamp()} {role} {operation} rc={result.returncode}\n{detail}\n')
            self.record({'event':'git_operation','agent':role,'operation':operation,'duration_ms':round((time.monotonic_ns()-started)/1e6,3),'exit_code':result.returncode})
            if result.returncode and not allow_fail:raise ValueError(f'{operation} 失败：{detail}')
            return result
        except subprocess.TimeoutExpired:raise ValueError(f'{operation} 超时。')
    def commit(self,role):
        if role not in WRITE_PATHS:raise ValueError('该角色不能提交代码。')
        queued=time.monotonic_ns()
        with self.git_lock:
            self.record({'event':'git_operation','agent':role,'operation':'等待 Git 操作锁','duration_ms':round((time.monotonic_ns()-queued)/1e6,3),'exit_code':0})
            # Include only existing files/directories. Fail closed on previously staged unrelated files.
            paths=[x for x in WRITE_PATHS[role] if (self.repos[role]/x).exists()]
            if not paths:raise ValueError('未发现允许提交的文件。')
            staged=self.git(role,'检查暂存文件',['diff','--cached','--name-only','-z']).stdout.split('\0')
            for name in filter(None,staged):
                if not any(name==x or (x.endswith('/') and name.startswith(x)) for x in WRITE_PATHS[role]):raise ValueError('存在不属于当前角色的暂存文件：'+name)
            self.git(role,'暂存工作',['add','-A','--',*paths])
            changed=self.git(role,'检查提交内容',['diff','--cached','--quiet'],allow_fail=True)
            if changed.returncode==0:raise ValueError('允许范围内没有可提交的代码变化。')
            if changed.returncode!=1:raise ValueError('无法检查暂存内容。')
            self.git(role,'提交工作',['commit','-m','Dillo experiment: '+role])
            sha=self.git(role,'读取提交',['rev-parse','HEAD']).stdout.strip()
            return {'commit':sha}
    def integrate(self,worker):
        if worker not in ('W1','W2','W3','W4'):raise ValueError('该 Worker 没有需要合并的代码提交。')
        queued=time.monotonic_ns()
        with self.git_lock:
            self.record({'event':'git_operation','agent':'leader','operation':'等待 Git 操作锁','duration_ms':round((time.monotonic_ns()-queued)/1e6,3),'exit_code':0})
            head=self.git(worker,'读取 Worker 提交',['rev-parse','HEAD']).stdout.strip()
            if head==APP_REV:raise ValueError(worker+' 没有新的已提交工作。')
            self.git('leader','获取 '+worker+' 提交',['-c','protocol.file.allow=always','fetch','--no-tags',self.repos[worker],'experiment/'+worker])
            result=self.git('leader','集成 '+worker,['cherry-pick','FETCH_HEAD'],allow_fail=True)
            if result.returncode:
                detail=self.git('leader','查看集成状态',['status','--short'],allow_fail=True).stdout
                raise ValueError('集成出现冲突，Leader 需修复后调用 continue-integration：'+detail)
            return {'worker':worker,'source_commit':head,'integrated_commit':self.git('leader','读取集成提交',['rev-parse','HEAD']).stdout.strip()}
    def continue_integration(self):
        queued=time.monotonic_ns()
        with self.git_lock:
            self.record({'event':'git_operation','agent':'leader','operation':'等待 Git 操作锁','duration_ms':round((time.monotonic_ns()-queued)/1e6,3),'exit_code':0})
            pending=self.git('leader','读取冲突文件',['diff','--name-only','--diff-filter=U','-z']).stdout.split('\0')
            pending=list(filter(None,pending))
            if pending:self.git('leader','暂存已解决冲突',['add','--',*pending])
            self.git('leader','完成冲突合并',['cherry-pick','--continue'])
            return {'commit':self.git('leader','读取集成提交',['rev-parse','HEAD']).stdout.strip()}
    def launch(self,role,prompt):
        if role not in ('leader',)+ROLES:raise ValueError('未知 Agent。')
        with self.lock:
            if role in self.procs:raise ValueError('该角色已经启动。')
            out=(self.raw/(role+'-events.jsonl')).open('w',encoding='utf-8');err=(self.raw/(role+'-stderr.log')).open('w',encoding='utf-8')
            # Separate CLI process, no native child agents or shared daemon.
            args=[self.codex,'--no-daemon','-a','never','exec','--json','--disable','multi_agent','--sandbox','workspace-write','-c','sandbox_workspace_write.network_access=true','-C',str(self.repos[role]),'-']
            if self.model:args[-1:-1]=['--model',self.model]
            if self.telemetry_enabled:args[-1:-1]=['-c',telemetry_config(self.metrics_endpoints[role])]
            try:process=subprocess.Popen(args,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=err,env=self.env,start_new_session=True,text=True,bufsize=1)
            except BaseException:out.close();err.close();raise
            self.procs[role]=process;self.runs[role]={'pid':process.pid,'start_ns':time.monotonic_ns(),'start_utc':stamp(),'exit_code':None}
            watcher=threading.Thread(target=self.watch,args=(role,process,out,err),daemon=True);self.watchers.append(watcher);watcher.start()
            try:process.stdin.write(prompt);process.stdin.close()
            except (OSError,BrokenPipeError):
                with contextlib.suppress(OSError):process.stdin.close()
                stop_group(process);raise
            emit(f'[Agent] {role} 已启动，PID {process.pid}。')
    def watch(self,role,p,out,err):
        calls={}
        try:
            for line in p.stdout:
                now=time.monotonic_ns();out.write(line);out.flush()
                try:e=json.loads(line)
                except ValueError:continue
                if not isinstance(e,dict):continue
                typ=e.get('type','');item=e.get('item') or {};item=item if isinstance(item,dict) else {}
                if typ in ('turn.completed','turn.failed'):
                    with self.lock:self.runs[role]['terminal_event']=typ
                ident=str(item.get('id') or '');kind=str(item.get('type') or '')
                if typ=='item.started' and ident:calls[ident]=(kind,now)
                elif typ in ('item.completed','item.failed') and ident:
                    old=calls.pop(ident,None)
                    if old:
                        with self.lock:self.tool_times.append({'agent':role,'item_id':ident,'kind':old[0],'duration_ms':round((now-old[1])/1e6,3),'event':typ})
                if typ=='turn.completed':
                    with self.lock:self.token_usage.append({'agent':role,'usage':e.get('usage',{})})
                if typ in ('turn.failed','error') or item.get('type')=='error':
                    self.record({'event':'agent_error','agent':role,'error':redacted(e.get('error') or e.get('message') or item.get('message') or '')})
        finally:
            p.wait();p.stdout.close();out.close();err.close()
            with self.lock:
                self.runs[role].update({'end_ns':time.monotonic_ns(),'end_utc':stamp(),'exit_code':p.returncode})
                if role in ROLES:
                    for topic in list(self.subs[role]):self.unsubscribe(role,topic,'process_exit')
                self.record({'event':'process_end','agent':role,'exit_code':p.returncode})
            emit(f'[Agent] {role} 已退出，状态码 {p.returncode}。')
    def status(self):
        with self.lock:return {r:{'state':'running' if p.poll() is None else 'exited','exit_code':p.poll(),'pid':p.pid} for r,p in self.procs.items()}
    def close(self):
        self.stop.set()
        with self.changed:self.changed.notify_all()
        for p in list(self.procs.values()):stop_group(p)
        for watcher in self.watchers:watcher.join(timeout=3)
        self.eventfile.close()

def bus_client(control,action,args):
    cfg=json.loads(pathlib.Path(control).read_text(encoding='utf-8'))
    payload={'token':cfg['token'],'action':action,'client_send_ns':time.monotonic_ns()}
    if action=='send':payload.update({'to':args.to,'text':args.text})
    elif action=='publish':payload.update({'topic':args.topic,'text':args.text})
    elif action in ('subscribe','unsubscribe'):payload['topic']=args.topic
    elif action=='poll':payload['wait']=args.wait
    elif action=='spawn':payload.update({'worker':args.worker,'text':args.text})
    elif action=='integrate':payload['worker']=args.worker
    raw=json.dumps(payload,ensure_ascii=False).encode('utf-8')
    req=urllib.request.Request(cfg['url'],data=raw,headers={'Content-Type':'application/json'},method='POST')
    try:
        with urllib.request.urlopen(req,timeout=25) as r: result=json.loads(r.read())
    except urllib.error.HTTPError as e: raise ExperimentError(e.read().decode('utf-8',errors='replace'))
    received=time.monotonic_ns()
    if action=='poll':
        for m in result.get('messages',[]):
            ack=json.dumps({'token':cfg['token'],'action':'ack','id':m['id'],'client_receive_ns':received}).encode('utf-8')
            req=urllib.request.Request(cfg['url'],data=ack,headers={'Content-Type':'application/json'},method='POST')
            with urllib.request.urlopen(req,timeout=15) as r:r.read()
    print(json.dumps(result,ensure_ascii=False))
    return 0

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self,*_):pass
    def do_POST(self):
        try:
            length=int(self.headers.get('Content-Length','0'))
            if self.path.startswith('/metrics/'):
                token=self.path.split('/')[2];role=self.server.tokens.get(token)
                if role is None or length<1 or length>8*1024*1024:raise ValueError('遥测请求不合法。')
                raw=self.rfile.read(length)
                if self.headers.get('Content-Encoding','').lower()=='gzip':
                    import gzip
                    raw=gzip.decompress(raw)
                    if len(raw)>16*1024*1024:raise ValueError('遥测解压后过大。')
                value=json.loads(raw)
                if self.server.state.start_ns:
                    with self.server.state.lock:
                        with (self.server.state.raw/(role+'-模型指标.jsonl')).open('a',encoding='utf-8') as out:out.write(json.dumps({'utc':stamp(),'payload':value},ensure_ascii=False)+'\n')
                body=b'{}';self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length','2');self.end_headers();self.wfile.write(body);return
            if length<1 or length>MAX_MESSAGE*2:raise ValueError('请求大小不合法。')
            raw=self.rfile.read(length);data=json.loads(raw)
            if not isinstance(data,dict):raise ValueError('请求格式错误。')
            role=self.server.tokens.get(data.get('token'));action=data.get('action')
            if role is None:raise ValueError('认证失败。')
            state=self.server.state
            if action=='send':
                target=data.get('to'); recipients=list(ROLES) if target=='all' and role=='leader' else [target]
                result={'id':state.deliver(role,recipients,data.get('text'),client_send_ns=data.get('client_send_ns'))}
            elif action=='publish':
                if role!='leader':raise ValueError('只有 Leader 可以按 Topic 分发。')
                topic=data.get('topic')
                if topic not in TOPICS:raise ValueError('未知 Topic。')
                with state.lock:recipients=[r for r in ROLES if topic in state.subs[r]]
                if not recipients:raise ValueError('该 Topic 当前没有订阅者。')
                result={'id':state.deliver(role,recipients,data.get('text'),topic=topic,client_send_ns=data.get('client_send_ns')),'recipients':recipients}
            elif action=='subscribe':state.subscribe(role,data.get('topic'));result={'ok':True}
            elif action=='unsubscribe':state.unsubscribe(role,data.get('topic'));result={'ok':True}
            elif action=='poll':result={'messages':state.poll(role,data.get('wait',0))}
            elif action=='ack':state.ack(role,data.get('id'),data.get('client_receive_ns'));result={'ok':True}
            elif action=='status':result={'agents':state.status(),'subscriptions':{k:sorted(v) for k,v in state.subs.items()}}
            elif action=='commit':result=state.commit(role)
            elif action=='integrate':
                if role!='leader':raise ValueError('只有 Leader 可以集成。')
                result=state.integrate(data.get('worker'))
            elif action=='continue-integration':
                if role!='leader':raise ValueError('只有 Leader 可以完成集成。')
                result=state.continue_integration()
            elif action=='spawn':
                if role!='leader':raise ValueError('只有 Leader 可以启动 Worker。')
                worker=data.get('worker');text=data.get('text')
                if worker not in ROLES:raise ValueError('未知 Worker。')
                with state.lock:
                    if worker in state.procs:raise ValueError('该 Worker 已启动。')
                    mid=state.deliver('leader',[worker],text,kind='dispatch',client_send_ns=data.get('client_send_ns'))
                    state.launch(worker,worker_prompt(state,worker))
                result={'id':mid,'worker':worker}
            else:raise ValueError('未知操作。')
            body=json.dumps(result,ensure_ascii=False).encode('utf-8')
            self.send_response(200);self.send_header('Content-Type','application/json; charset=utf-8');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
            state.record({'event':'http','agent':role,'action':action,'request_body_bytes':length,'response_body_bytes':len(body)})
        except (ValueError,KeyError,TypeError,json.JSONDecodeError,ExperimentError,OSError) as e:
            body=json.dumps({'error':redacted(e)},ensure_ascii=False).encode('utf-8')
            try:self.send_response(400);self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
            except (OSError,BrokenPipeError):pass

class Server(http.server.ThreadingHTTPServer):
    daemon_threads=True

def script_command(state,role):
    return shlex.quote(sys.executable)+' '+shlex.quote(str(pathlib.Path(__file__).resolve()))+' --agent --control '+shlex.quote(str(state.repos[role]/'.experiment-build/control.json'))

def telemetry_config(endpoint):
    return 'otel.metrics_exporter={otlp-http={endpoint='+json.dumps(endpoint)+',protocol="json"}}'

SPEC='''
项目 Dillo 固定版本；任务：正确支持 HTTP Content-Disposition 的 UTF-8 扩展文件名 filename*。
规范：合法 filename*=UTF-8''foo-%c3%a4.txt 优先于 filename="fallback.txt"，结果为 foo-ä.txt；仅 filename* 也能工作；参数顺序和大小写可变。非法百分号、无效 UTF-8、不支持的字符集、空值或 NUL 必须回退普通 filename；编码路径分隔符、控制字符、.. 等必须安全处理。原始普通 filename 行为保留。只提交实验工作区，禁止推送、部署或修改用户其他项目。正式任务必须真实编码、测试、审查和集成，不能杜撰结果或为了增加消息填充无用内容。
'''
ASSIGN={
'W1':'''实现解析器，修改 src/misc.h（必要时 dlib/ 文件）；兼容既有接口。先发送接口与设计；关注路径安全、UTF-8 合法性和内存管理。运行可用测试并提交。只能提交你的实现范围。''',
'W2':'''负责 test/unit/disposition.c：依据任务写普通 filename 与 filename* 的回归用例，并更新原来显式预期 fallback 的测试；在 W1 未合并时预期失败须说明，不得伪造通过。只提交该测试文件。''',
'W3':'''独立安全审查，创建 test/unit/disposition_security.c 可独立编译运行，覆盖无效转义、NUL、路径分隔符、..、无效 UTF-8、回退；成功打印 SECURITY_CASES_PASSED=<非零整数>，失败时非零退出。测试基于实际公开函数，发现问题发给 Leader。只提交该文件。''',
'W4':'''检查 src/cache.c 到 src/uicmd.cc 的头部与保存建议名调用链，创建 test/unit/disposition_http_test.py：只用 Python 标准库与本机 C 编译器，本机临时 HTTP 服务发送实际 Content-Disposition，测试客户端读取头部后调用实际编译的解析器并核对建议名。成功时打印 HTTP_CASES_PASSED=<非零整数>；失败时非零退出。报告该轻量测试不等于完整 GUI 验证。只提交这个文件。''',
'W5':'''独立审查：先查看基线和验收，再等待 Leader 发送已集成的提交或目录；核对实际 diff、潜在安全和回归问题。发送可复现问题或明确结论。不要改动代码；如果 Leader 无法提供结果，应如实报告未审查。'''
}

def worker_prompt(state,role):
    client=script_command(state,role); repo=state.repos[role]
    own_topic={'W1':'download/parser','W2':'download/tests','W3':'download/security','W4':'download/integration','W5':'download/tests'}[role]
    return f'''你是本地多 Agent 浏览器开发实验中的 {role}，运行独立的 Codex CLI，当前目录 {repo}。\n你的职责：{ASSIGN[role]}\n任务的共享验收契约由 Leader 通过 download/contract Topic 发给你，收到之前不要修改代码。\n
真实通信必须经过本机 Leader 路由。以下是你的客户端命令前缀：\n{client}\n
先运行：{client} poll --wait 10 读取 Leader 分派并确认收到；然后分别运行 {client} subscribe --topic download/contract 和 {client} subscribe --topic {own_topic}。用 {client} send --to leader --text '已收到分派并订阅共享契约' 通知 Leader，接着用 {client} poll --wait 10 等待真实的 download/contract 消息（可重复等待），收到后才开始工作；等待超过 3 分钟仍未收到就向 Leader 报告阻塞并结束。只向 Leader 汇报实际进展、边界、测试或阻塞。禁止直接联系其他 Worker。需要处理 Leader 的实际反馈时，用 poll 读取；不要杜撰。W1–W4 完成代码和测试后使用 {client} commit，由本机实验服务在你自己的隔离仓库中只提交角色允许的文件，返回提交哈希；不需要直接写 Git 元数据。W5 不提交。完成后向 Leader 发送实际提交哈希、改动、运行过的命令和真实结果。测试依赖用 cc -std=gnu11 -I.experiment-build -I. test/unit/disposition.c dlib/dlib.c -o .experiment-build/check；不需要 sudo。完成或阻塞后以清晰摘要结束。W5 必须等待 Leader 通过通道发送集成结果后审查，最多等待 45 分钟；不要伪造审查。
'''

def leader_prompt(state):
    client=script_command(state,'leader');base=state.root/'workers'
    return f'''你是 Dillo 开发实验的真实 Codex Leader，负责分派、协调、验收、集成，当前目录 {state.repos['leader']}。\n{SPEC}\n
本实验启用独立 Codex Worker 进程，不能使用原生 spawn_agent 替代。你的控制客户端前缀：\n{client}\n
首先逐个启动 W1 W2 W3 W4 W5：例如 {client} spawn W1 --text '请实现解析器并汇报接口、提交和测试'；其他角色分别是测试、安全审查、HTTP 轻量集成验证、独立审查。必须启动五个真正的 Worker，不能由你代替。命令成功才表示进程启动；他们通过此通道回报，不直接向其他 Worker 发消息。每个 Worker 独立目录在 {base}/W1 ... W5，分支是 experiment/W1 等。
使用 {client} poll --wait 10 查看消息，用 {client} status 查看真实状态；确认各 Worker 订阅 download/contract 后，务必使用 {client} publish --topic download/contract --text '完整共享验收契约' 向他们发送上面完整的任务规范，包含 filename* 优先级、非法编码回退和路径安全要求；这是 Worker 开始工作的必要依据，不是为了制造流量。用 {client} send --to W1 --text '...' 给相应 Worker 反馈。只转发真正有用的信息，发现失败则安排修复。注意轮询前输出可能暂无，持续等待任务完成，最多 100 分钟。

Worker 完成后，在当前 Leader 工作区分别用 {client} integrate W1、{client} integrate W2、{client} integrate W3、{client} integrate W4，由本机服务从各 Worker 的本地仓库获取并集成实际提交，避免在 Codex 沙箱内写 Git 元数据。先确认日志、范围与结果；W5 只审查，负责最终复核。若集成冲突，先修改冲突文件，再用 {client} continue-integration；若无法解决必须回报，禁止伪造结果。先整合 W1/W2/W3/W4，并运行编译/测试，再向 W5 发消息说明当前 Leader 目录与集成提交，并等待 W5 实际审查；若发现问题负责修复和重测，Lead 自己修复后用 {client} commit 提交允许范围的改动。测试命令示例：cc -std=gnu11 -I.experiment-build -I. test/unit/disposition.c dlib/dlib.c -o .experiment-build/check && .experiment-build/check。W3 的安全测试和 W4 的 HTTP 测试必须实际运行。所有需要的临时构建物保存在 .experiment-build/；不得推送或发布。最后报告每个 Worker 的真实结果、命令、提交和限制；若无法完成明确报错。
'''

def parse_ps_time(text):
    try:
        days=0
        if '-' in text:
            day,text=text.split('-',1);days=int(day)
        parts=[float(x) for x in text.split(':')];total=0
        for value in parts:total=total*60+value
        return days*86400+total
    except (ValueError,TypeError):return None

def sample_resources(state,interval=1):
    previous={};previous_t=None;next_system=0
    while not state.stop.is_set():
        started=time.monotonic();sample_ns=time.monotonic_ns()
        try:
            p=subprocess.run(['ps','-axo','pid=,ppid=,time=,rss='],capture_output=True,text=True,timeout=5)
            processes={}
            for ln in p.stdout.splitlines():
                parts=ln.split()
                if len(parts)!=4 or not parts[0].isdigit() or not parts[1].isdigit():continue
                cpu=parse_ps_time(parts[2])
                if cpu is None:continue
                processes[int(parts[0])]=(int(parts[1]),cpu,int(parts[3]))
            with state.lock:roots={'router':os.getpid(),**{r:p.pid for r,p in state.procs.items() if p.poll() is None}}
            owners={pid:role for role,pid in roots.items()}
            changed=True
            while changed:
                changed=False
                for pid,(parent,_,_) in processes.items():
                    if pid not in owners and parent in owners:owners[pid]=owners[parent];changed=True
            elapsed=started-previous_t if previous_t is not None else None
            for role in ('router','leader')+ROLES:
                selected=[(pid,data) for pid,data in processes.items() if owners.get(pid)==role]
                if not selected:continue
                delta=0.0
                for pid,(_,cputime,_) in selected:
                    before=previous.get(pid)
                    delta+=max(0,cputime-before) if before is not None else cputime
                row={'utc':stamp(),'mono_ns':sample_ns,'agent':role,'processes':len(selected),'rss_kib':sum(x[1][2] for x in selected),'cpu_percent':round(delta/elapsed*100,2) if elapsed and elapsed>0 else '','note':'进程树采样；不包含远程模型和共享外部服务'}
                with state.lock:state.sample_rows.append(row)
            previous={pid:cpu for pid,(_,cpu,_) in processes.items() if pid in owners};previous_t=started
        except (OSError,ValueError,subprocess.SubprocessError) as e:state.record({'event':'sample_error','error':redacted(e)})
        if started>=next_system:
            snapshot=system_snapshot()
            with state.lock:state.system_rows.append(snapshot)
            next_system=started+5
        state.stop.wait(max(.1,interval-(time.monotonic()-started)))

ACCEPTANCE=r'''
#include <stdio.h>
#include <string.h>
#include "src/misc.h"
static int failures=0, tests=0;
static void check(const char *header,const char *expected) {
    char *type=NULL,*name=NULL; tests++;
    a_Misc_parse_content_disposition(header,&type,&name);
    if (!type || strcmp(type,"attachment") || !name || strcmp(name,expected)) {
        fprintf(stderr,"FAIL case %d: expected %s, got %s\n",tests,expected,name?name:"NULL");failures++;
    }
    dFree(type);dFree(name);
}
static void safe_name(const char *header) {
    char *type=NULL,*name=NULL; tests++;
    a_Misc_parse_content_disposition(header,&type,&name);
    if (name && (strchr(name,'/') || strchr(name,'\\') || !strcmp(name,"..") || !strcmp(name,"."))) {
        fprintf(stderr,"FAIL case %d: unsafe filename\n",tests);failures++;
    }
    dFree(type);dFree(name);
}
int main(void) {
    check("attachment; filename=\"fallback.txt\"; filename*=UTF-8''foo-%c3%a4.txt","foo-ä.txt");
    check("attachment; filename*=UTF-8''hello.txt","hello.txt");
    check("attachment; filename*=UTF-8''hello.txt; filename=\"fallback.txt\"","hello.txt");
    check("attachment; FILENAME*=UTF-8''hello.txt; filename=\"fallback.txt\"","hello.txt");
    check("attachment; filename=\"fallback.txt\"; filename*=UTF-8''bad%ZZ.txt","fallback.txt");
    check("attachment; filename=\"fallback.txt\"; filename*=UTF-8''bad%00evil.txt","fallback.txt");
    check("attachment; filename=\"fallback.txt\"; filename*=UTF-8''bad%C3%28.txt","fallback.txt");
    check("attachment; filename=\"fallback.txt\"; filename*=ISO-8859-1''foo%E4.txt","fallback.txt");
    check("attachment; filename=\"normal.txt\"","normal.txt");
    safe_name("attachment; filename*=UTF-8''..%2Fsecret.txt");
    safe_name("attachment; filename*=UTF-8''evil%5Csecret.txt");
    printf("ACCEPTANCE_CASES=%d FAILED=%d\n",tests,failures);
    return failures ? 1 : 0;
}
'''

def final_checks(repo,cc,root,repos=None):
    log=root/'测试/最终验证.log';build=repo/'.experiment-build';results={}
    def check(label,argv,required=True):
        emit('[验证] '+label)
        try:rc=run(argv,cwd=repo,log=log,timeout=300,allow_fail=True)
        except (OSError,ExperimentError) as e:rc=1;emit('[验证] '+redacted(e))
        results[label]={'exit_code':rc,'passed':rc==0,'required':required}
        return rc==0
    exe=build/'disposition-final'
    if check('编译上游回归测试',[cc,'-std=gnu11','-I'+str(build),'-I.','test/unit/disposition.c','dlib/dlib.c','-o',exe]):check('上游回归测试',[exe])
    else:results['上游回归测试']={'passed':False,'exit_code':None,'required':True}
    path=build/'acceptance.c';path.write_text(ACCEPTANCE,encoding='utf-8');exe=build/'acceptance'
    if check('编译独立验收测试',[cc,'-std=gnu11','-I'+str(build),'-I.',path,'dlib/dlib.c','-o',exe]):check('独立验收测试',[exe])
    else:results['独立验收测试']={'passed':False,'exit_code':None,'required':True}
    security=repo/'test/unit/disposition_security.c';exe=build/'security'
    if security.is_file():
        if check('编译安全边界测试',[cc,'-std=gnu11','-I'+str(build),'-I.',security,'dlib/dlib.c','-o',exe]):
            start=log.stat().st_size if log.exists() else 0;passed=check('安全边界测试',[exe])
            with log.open('rb') as f:f.seek(start);chunk=f.read().decode('utf-8',errors='replace')
            count=re.search(r'SECURITY_CASES_PASSED\s*=\s*([0-9]+)',chunk)
            if not passed or not count or int(count.group(1))<1:
                results['安全边界测试'].update({'passed':False,'detail':'未找到非零 SECURITY_CASES_PASSED，或测试失败'})
        else:results['安全边界测试']={'passed':False,'exit_code':None,'required':True}
    else:results['安全边界测试']={'passed':False,'exit_code':None,'required':True,'detail':'Worker 安全测试文件不存在'}
    integration=repo/'test/unit/disposition_http_test.py'
    if integration.is_file():
        start=log.stat().st_size if log.exists() else 0
        passed=check('HTTP 头部集成测试',[sys.executable,integration])
        with log.open('rb') as f:f.seek(start);chunk=f.read().decode('utf-8',errors='replace')
        count=re.search(r'HTTP_CASES_PASSED\s*=\s*([0-9]+)',chunk)
        if not passed or not count or int(count.group(1))<1:
            results['HTTP 头部集成测试'].update({'passed':False,'detail':'未找到非零 HTTP_CASES_PASSED，或测试失败'})
    else:results['HTTP 头部集成测试']={'passed':False,'exit_code':None,'required':True,'detail':'HTTP 集成测试文件不存在'}
    diff=subprocess.run(['git','diff','--stat',APP_REV,'HEAD'],cwd=repo,capture_output=True,text=True,timeout=30)
    (root/'测试/代码变更.txt').write_text(diff.stdout+diff.stderr,encoding='utf-8')
    changes=subprocess.run(['git','diff','--name-only',APP_REV,'HEAD','--','src/misc.h'],cwd=repo,capture_output=True,text=True,timeout=30)
    results['集成真实解析器代码']={'passed':bool(changes.stdout.strip()),'exit_code':changes.returncode,'required':True}
    try:
        source=(repo/'test/unit/disposition.c').read_text(encoding='utf-8')
        part=source[source.index('struct testcase cases[]'):source.index('static int equal')]
        count=len(re.findall(r'^\s*\{',part,re.M))
    except (OSError,ValueError):count=0
    results['保留上游回归用例']={'passed':count>=75,'exit_code':0 if count>=75 else 1,'required':True,'detail':f'当前识别到 {count} 条，上游基线为 75 条'}
    if repos:
        expected={'W1':['src/misc.h','dlib/'],'W2':['test/unit/disposition.c'],'W3':['test/unit/disposition_security.c'],'W4':['test/unit/disposition_http_test.py']}
        for role,paths in expected.items():
            p=subprocess.run(['git','diff','--name-only',APP_REV,'HEAD','--',*paths],cwd=repos[role],capture_output=True,text=True,timeout=30)
            files=[x for x in p.stdout.splitlines() if x]
            results[role+' 实际提交工作']={'passed':p.returncode==0 and bool(files),'exit_code':p.returncode,'required':True,'detail':'、'.join(files) if files else '未发现预期文件的已提交变更'}
    return results

def metrics_from_stderr(path,role):
    out=[]
    if not path.exists():return out
    pats=[('模型服务推理 engine_service_total_ms',r'engine_service_total_ms[\s=:"\']+([0-9]+(?:\.[0-9]+)?)'),('模型首 token ttft_ms',r'\bttft_ms[\s=:"\']+([0-9]+(?:\.[0-9]+)?)')]
    for line_no,line in enumerate(path.read_text(encoding='utf-8',errors='replace').splitlines(),1):
        for name,pat in pats:
            m=re.search(pat,line)
            if m:out.append({'agent':role,'metric':name,'duration_ms':float(m.group(1)),'source':path.name,'line':line_no})
        if 'codex.api_request' in line:
            m=re.search(r'duration_ms[\s=:"\']+([0-9]+(?:\.[0-9]+)?)',line)
            if m:out.append({'agent':role,'metric':'模型 API 请求时间（含连接，非纯推理）','duration_ms':float(m.group(1)),'source':path.name,'line':line_no})
    return out

def metrics_from_otlp(path,role):
    """Use the last cumulative histogram for each attribute set; never sum exports twice."""
    latest={}
    if not path.exists():return []
    for line in path.read_text(encoding='utf-8',errors='replace').splitlines():
        try:value=json.loads(line)['payload']
        except (ValueError,KeyError,TypeError):continue
        if not isinstance(value,dict):continue
        for resource in value.get('resourceMetrics',[]):
            for scope in resource.get('scopeMetrics',[]):
                for metric in scope.get('metrics',[]):
                    name=metric.get('name','')
                    if not any(x in name for x in ('responses_api_inference_time','responses_api_engine_','responses_api_overhead','api_request.duration','websocket.request.duration')):continue
                    hist=metric.get('histogram') or {};points=hist.get('dataPoints') or hist.get('data_points') or []
                    for p in points:
                        try:count=int(p.get('count',0));total=float(p.get('sum',0))
                        except (ValueError,TypeError):continue
                        if count<=0:continue
                        key=(name,json.dumps(p.get('attributes',[]),sort_keys=True))
                        latest[key]={'count':count,'sum':total,'min':p.get('min'),'max':p.get('max')}
    grouped={}
    for (name,_),v in latest.items():
        g=grouped.setdefault(name,{'agent':role,'metric':name,'count':0,'sum_ms':0.0,'min_ms':None,'max_ms':None,'source':path.name})
        g['count']+=v['count'];g['sum_ms']+=v['sum']
        if isinstance(v['min'],(int,float)):g['min_ms']=v['min'] if g['min_ms'] is None else min(g['min_ms'],v['min'])
        if isinstance(v['max'],(int,float)):g['max_ms']=v['max'] if g['max_ms'] is None else max(g['max_ms'],v['max'])
    for row in grouped.values():row['average_ms']=round(row['sum_ms']/row['count'],3)
    return list(grouped.values())

def percentile(vals):
    vals=sorted(vals)
    if not vals:return '无可用样本'
    s=f'n={len(vals)}，中位数 {statistics.median(vals):.3f} ms，最大 {vals[-1]:.3f} ms'
    if len(vals)>=20:s+=f'，P95 {vals[math.ceil(.95*len(vals))-1]:.3f} ms'
    if len(vals)>=100:s+=f'，P99 {vals[math.ceil(.99*len(vals))-1]:.3f} ms'
    return s

def make_report(state,info):
    root=state.root; rec=state.raw
    with state.lock:
        messages=list(state.messages.values());events=list(state.events);runs=dict(state.runs);samples=list(state.sample_rows);system_samples=list(state.system_rows);tools=list(state.tool_times);usage=list(state.token_usage)
    end=state.end_ns or time.monotonic_ns();elapsed=(end-state.start_ns)/1e9 if state.start_ns else None
    fields=['id','kind','sender','receiver','topic','body_bytes','text','sender_to_service_ms','service_route_ms','queue_ms','service_to_client_ms','sender_to_client_ms','delivery_status']
    rows=[]
    for m in messages:
        for recipient in m['recipients']:
            d=m['deliveries'][recipient];sent=m.get('client_send_ns');recv=m['service_recv_ns'];enq=d.get('enqueued_ns');deq=d.get('dequeue_ns');got=d.get('client_receive_ns')
            def ms(a,b):return round((b-a)/1e6,3) if isinstance(a,int) and isinstance(b,int) and b>=a else ''
            rows.append({'id':m['id'],'kind':m['kind'],'sender':m['sender'],'receiver':recipient,'topic':m['topic'],'body_bytes':m['body_bytes'],'text':m['text'],'sender_to_service_ms':ms(sent,recv),'service_route_ms':ms(recv,enq),'queue_ms':ms(enq,deq),'service_to_client_ms':ms(deq,got),'sender_to_client_ms':ms(sent,got),'delivery_status':'客户端已领取并确认' if got else ('服务已出队，未收到确认' if deq else '仍待领取')})
    write_csv(rec/'消息明细.csv',fields,rows)
    subscriptions=[x for x in events if x.get('event') in ('subscribe','unsubscribe')]
    write_csv(rec/'订阅事件.csv',['utc','mono_ns','agent','event','topic','origin'],subscriptions)
    write_csv(rec/'每Agent资源.csv',['utc','mono_ns','agent','processes','rss_kib','cpu_percent','note'],samples)
    write_csv(rec/'系统内存采样.csv',['utc','mono_ns','swap_usage','vm_stat'],system_samples)
    write_csv(rec/'工具耗时.csv',['agent','item_id','kind','duration_ms','event'],tools)
    gitops=[x for x in events if x.get('event')=='git_operation']
    write_csv(rec/'Git操作耗时.csv',['utc','agent','operation','duration_ms','exit_code'],gitops)
    model=[]
    for role in ('leader',)+ROLES:model.extend(metrics_from_stderr(rec/(role+'-stderr.log'),role))
    write_csv(rec/'模型遥测.csv',['agent','metric','duration_ms','source','line'],model)
    model_hist=[]
    for role in ('leader',)+ROLES:model_hist.extend(metrics_from_otlp(rec/(role+'-模型指标.jsonl'),role))
    write_csv(rec/'模型指标汇总.csv',['agent','metric','count','sum_ms','average_ms','min_ms','max_ms','source'],model_hist)
    bins=collections.defaultdict(lambda:{'request_body_bytes':0,'response_body_bytes':0,'delivered_text_bytes':0,'delivered_messages':0,'worker_to_leader_offered_bytes':0,'leader_to_worker_offered_bytes':0,'worker_to_leader_offered_copies':0,'leader_to_worker_offered_copies':0})
    for e in events:
        if not state.start_ns:continue
        sec=max(0,(e['mono_ns']-state.start_ns)//1_000_000_000)
        if e['event']=='http':
            bins[sec]['request_body_bytes']+=e.get('request_body_bytes',0);bins[sec]['response_body_bytes']+=e.get('response_body_bytes',0)
        elif e['event']=='enqueue':
            direction=('worker_to_leader' if e.get('sender') in ROLES and e.get('receiver')=='leader' else ('leader_to_worker' if e.get('sender')=='leader' and e.get('receiver') in ROLES else None))
            if direction:
                bins[sec][direction+'_offered_bytes']+=e.get('body_bytes',0)
                bins[sec][direction+'_offered_copies']+=1
        elif e['event']=='receive_ack':
            m=state.messages.get(e.get('id'))
            if m:bins[sec]['delivered_text_bytes']+=m['body_bytes'];bins[sec]['delivered_messages']+=1
    bw=[]
    for sec in range(math.ceil(elapsed or 0)):
        b=bins[sec];bw.append({'second':sec,**b,'http_json_mbps':round((b['request_body_bytes']+b['response_body_bytes'])*8/1e6,6),'delivered_text_mbps':round(b['delivered_text_bytes']*8/1e6,6)})
    write_csv(rec/'每秒通信速率.csv',['second','request_body_bytes','response_body_bytes','delivered_text_bytes','delivered_messages','http_json_mbps','delivered_text_mbps','worker_to_leader_offered_bytes','worker_to_leader_offered_copies','leader_to_worker_offered_bytes','leader_to_worker_offered_copies'],bw)
    checks=info.get('checks') or {}; good=[r for r in rows if r['delivery_status']=='客户端已领取并确认'];parts=[]
    e=html.escape
    def para(s):parts.append('<p>'+e(str(s))+'</p>')
    def heading(s):parts.append('<h2>'+e(str(s))+'</h2>')
    def table(head,body):
        parts.append('<table><thead><tr>'+''.join('<th>'+e(str(x))+'</th>' for x in head)+'</tr></thead><tbody>')
        for row in body:parts.append('<tr>'+''.join('<td>'+e(str(x))+'</td>' for x in row)+'</tr>')
        if not body:parts.append('<tr><td colspan="'+str(len(head))+'">无可用样本</td></tr>')
        parts.append('</tbody></table>')
    parts.append('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>Dillo 多 Agent 实验报告</title><style>body{font:16px system-ui;max-width:1150px;margin:32px auto;padding:0 20px;line-height:1.55}table{border-collapse:collapse;width:100%}th,td{border:1px solid #bbb;padding:7px;text-align:left;vertical-align:top;word-break:break-word}th{background:#eef3f8}code{word-break:break-all}</style><h1>Dillo 浏览器多 Agent 实验报告</h1>')
    para('运行状态：'+str(info.get('status','未完成'))+'。'+str(info.get('detail','')))
    para('应用：Dillo '+APP_REV+'；使用独立 Codex CLI Leader 与 Worker、本实验本机路由服务；不是 Codex 原生子 Agent 通道，也不是 Cursor 原始实验。')
    para('Codex 版本：'+str(info.get('codex_version','未知'))+'；正式任务模型：'+str(info.get('model_selection','未知'))+'；本机 OTLP 遥测：'+('启用' if info.get('otel_local_enabled') else '未启用或未通过检查')+'。')
    host=info.get('host',{})
    para('主机：'+str(host.get('machine','未知'))+'；物理 CPU 核心 '+str(host.get('physical_cpus') or '不可得')+'；逻辑 CPU '+str(host.get('logical_cpus') or '不可得')+'；内存 '+(f"{host['memory_bytes']/1024**3:.1f} GiB" if host.get('memory_bytes') else '不可得')+'。系统内存原始计数每约 5 秒采集，见记录/系统内存采样.csv；准备结束的快照见实验状态.json。')
    para('正式任务耗时：'+(f'{elapsed:.3f} 秒（从 Leader 启动到开发及最终验证结束）' if elapsed is not None else '未开始')+'。下载、安装、登录、基线测试不计入。')
    heading('正式任务阶段耗时')
    stage=[]
    if state.start_ns and runs.get('leader',{}).get('end_ns'):
        stage.append(['Leader 开发与集成',(runs['leader']['end_ns']-state.start_ns)/1e9,'包含模型、工具执行和等待；与 Worker 耗时重叠'])
    if info.get('post_leader_wait_seconds') is not None:stage.append(['Leader 结束后等待 Worker',info['post_leader_wait_seconds'],'与未结束的 Worker 生命周期重叠'])
    if info.get('validation_seconds') is not None:stage.append(['脚本独立验证',info['validation_seconds'],'在 Leader 结束后进行'])
    table(['阶段','秒','说明'],[[a,f'{b:.3f}',c] for a,b,c in stage])
    heading('Agent 运行与 CPU')
    agent_rows=[]
    for role in ('router','leader')+ROLES:
        r=runs.get(role);rs=[x for x in samples if x['agent']==role];v=[x['cpu_percent'] for x in rs if isinstance(x['cpu_percent'],(int,float))]
        pid=os.getpid() if role=='router' else (r.get('pid') if r else '未启动')
        status='本机实验服务' if role=='router' else (r.get('exit_code') if r else '未启动')
        duration=('%.3f'%elapsed if elapsed is not None else '不可得') if role=='router' else (('%.3f'%((r.get('end_ns',end)-r['start_ns'])/1e9)) if r else '未启动')
        agent_rows.append([role,pid,status,duration,len(rs),('%.2f%%'%statistics.mean(v)) if v else '不可得',('%.2f%%'%max(v)) if v else '不可得',('%.1f MiB'%(max(x['rss_kib'] for x in rs)/1024)) if rs else '不可得'])
    table(['Agent','PID','退出码/身份','运行秒数','采样次数','CPU 平均','CPU 峰值','RSS 峰值'],agent_rows)
    points=[]
    for role in ROLES:
        r=runs.get(role) or {};a=r.get('start_ns');b=r.get('end_ns')
        if isinstance(a,int) and isinstance(b,int) and b>=a:points.extend([(a,1),(b,-1)])
    current=peak=0
    for _,change in sorted(points):current+=change;peak=max(peak,current)
    para('按独立 CLI 进程起止时间计算的 Worker 并发峰值：'+str(peak)+'；这是进程生命周期的重叠，不证明模型一直处于活跃推理。')
    para('每 Agent 使用独立 Codex CLI 的进程树归属；1 个 CPU 核为 100%，多核可超过 100%。采样约每秒，可能漏掉短进程；共享守护进程及远程模型资源不在该 Agent 内。router 行包含路由、采样及脚本启动的独立验证，不是纯路由 CPU。RSS 相加可能重复计算共享内存。')
    heading('协作消息与内容')
    para(f'独立消息 {len(messages)} 条；逐接收者投递 {len(rows)} 份，其中已领取并确认 {len(good)} 份，确认正文总量 {sum(r["body_bytes"] for r in good):,} 字节。未领取不当作成功。')
    direction=collections.defaultdict(lambda:[0,0])
    for r in good:
        key='Leader → Worker' if r['sender']=='leader' and r['receiver'] in ROLES else ('Worker → Leader' if r['sender'] in ROLES and r['receiver']=='leader' else '其他')
        direction[key][0]+=1;direction[key][1]+=r['body_bytes']
    table(['方向','确认的消息副本','正文 UTF-8 字节'],[[k,v[0],v[1]] for k,v in sorted(direction.items())])
    per_agent=[]
    for role in ('leader',)+ROLES:
        a=[r for r in good if r['sender']==role];b=[r for r in good if r['receiver']==role]
        per_agent.append([role,len(a),sum(x['body_bytes'] for x in a),len(b),sum(x['body_bytes'] for x in b)])
    table(['Agent','发出副本','发出正文 B','接收副本','接收正文 B'],per_agent)
    table(['发送方','接收方','类型/Topic','正文 UTF-8 字节','状态','内容摘录'],[[r['sender'],r['receiver'],r['kind']+' '+r['topic'],r['body_bytes'],r['delivery_status'],r['text'][:300]] for r in rows[:30]])
    para('完整正文、方向和逐接收者结果见 记录/消息明细.csv；同一广播会按接收者分别计数。自动注入给 CLI 的初始提示词不经本路由，未计入路由消息；绕过本路由的其他通讯不能由该路由记录证明不存在。')
    table(['Agent','Topic','订阅操作','来源','时间'],[[x.get('agent'),x.get('topic'),x.get('event'),x.get('origin','agent'),x.get('utc')] for x in subscriptions])
    heading('通信数据量与速率')
    req=sum(b['request_body_bytes'] for b in bw);resp=sum(b['response_body_bytes'] for b in bw);delivered=sum(r['body_bytes'] for r in good)
    table(['指标','结果'],[['路由 HTTP 请求 JSON 正文',f'{req:,} 字节'],['路由 HTTP 响应 JSON 正文',f'{resp:,} 字节'],['成功领取的消息正文副本',f'{delivered:,} 字节'],['HTTP JSON 正文全周期平均',f'{(req+resp)*8/(elapsed or 1)/1e6:.6f} Mbps' if elapsed else '不可得'],['HTTP JSON 正文单秒峰值',f'{max((x["http_json_mbps"] for x in bw),default=0):.6f} Mbps' if bw else '不可得']])
    para('每秒通信速率.csv 给出应用层 JSON 与消息正文；包含客户端与路由服务的本机 HTTP 正文，不含遥测导出、HTTP 头、TCP、重传与物理网卡流量。上下行相加是本地应用层工作量，不能与 10 Gbps 全双工单方向链路直接比较。')
    directional=[]
    for key,label in [('worker_to_leader','Worker → Leader'),('leader_to_worker','Leader → Worker')]:
        n=sum(b[key+'_offered_bytes'] for b in bw);copies=sum(b[key+'_offered_copies'] for b in bw)
        peak=max((b[key+'_offered_bytes'] for b in bw),default=0)*8/1e6
        directional.append([label,copies,f'{n:,}',f'{n*8/(elapsed or 1)/1e6:.6f}' if elapsed else '不可得',f'{peak:.6f}'])
    table(['方向','入队副本数','入队正文 B','全周期平均 Mbps','固定单秒峰值 Mbps'],directional)
    para('上表按服务入队时间、每个接收者一份统计提交的正文负载，包含尚未领取的消息；Topic 扇出按接收者分别计算。它用于容量估算，不含初始提示、JSON 信封和真实网络协议，不代表实际物理链路吞吐。固定单秒峰值可能低估跨秒突发。')
    heading('延迟拆分')
    latency=[]
    for col,label in [('sender_to_service_ms','客户端发送至服务接收'),('service_route_ms','服务路由入队'),('queue_ms','入队至接收方轮询领取（含等待）'),('service_to_client_ms','服务出队至客户端收到（含本机调度）'),('sender_to_client_ms','发送至客户端收到（含排队及调度）')]:
        vals=[r[col] for r in rows if isinstance(r[col],(int,float))];latency.append([label,percentile(vals)])
    table(['阶段','统计'],latency)
    per_kind=collections.defaultdict(list)
    for r in rows:
        if isinstance(r['sender_to_client_ms'],(int,float)):per_kind[r['kind']].append(r['sender_to_client_ms'])
    table(['消息类型','发送至领取确认耗时'],[[kind,percentile(vals)] for kind,vals in sorted(per_kind.items())])
    para('同一台机器的单调时钟配对；领取确认由客户端工具产生，不保证内容已进入模型或被理解。队列等待和工具进程启动不等于网络传播延迟。')
    grouped=collections.defaultdict(list)
    for t in tools:grouped[(t['agent'],t['kind'])].append(t['duration_ms'])
    table(['Agent','Codex 工具事件','执行耗时'],[[a,k,percentile(v)] for (a,k),v in sorted(grouped.items())])
    table(['Agent','本机 Git 处理','耗时 ms','退出码'],[[g.get('agent'),g.get('operation'),g.get('duration_ms'),g.get('exit_code')] for g in gitops])
    heading('模型请求与推理')
    modelgroups=collections.defaultdict(list)
    for m in model:modelgroups[(m['agent'],m['metric'])].append(m['duration_ms'])
    table(['Agent','模型可用遥测','统计'],[[a,k,percentile(v)] for (a,k),v in sorted(modelgroups.items())])
    table(['Agent','Codex OTLP 模型指标','样本','平均 ms','最小 ms','最大 ms'],[[r['agent'],r['metric'],r['count'],r['average_ms'],r['min_ms'] if r['min_ms'] is not None else '不可得',r['max_ms'] if r['max_ms'] is not None else '不可得'] for r in model_hist])
    inference_agents={x['agent'] for x in model if 'engine_service_total_ms' in x['metric']} | {x['agent'] for x in model_hist if 'responses_api_inference_time' in x['metric']}
    missing=[r for r in ('leader',)+ROLES if r in runs and r not in inference_agents]
    if missing:para('下列 Agent 没有取得可识别的模型服务推理时长：'+', '.join(missing)+'；不能从 Agent 运行时间、API 请求或 wait 推算为纯模型推理。')
    para('模型请求时间可能包含网络、排队和服务处理。远端服务没有提供单独推理指标时，此项保留不可得。Codex turn.completed 的 token 用量记录在实验状态.json。')
    heading('测试和完成情况')
    table(['验证','结果','说明'],[[k,'通过' if v.get('passed') else '未通过或未执行',v.get('detail','')] for k,v in checks.items()])
    para('HTTP 测试是本机 HTTP 头部与解析器集成，不等同真实浏览器 GUI。完整 Dillo/GUI 与跨服务器网络尚未测试。')
    para('原始代码、测试、完整消息和日志可能含敏感信息；文件保存在本机实验目录，请按需清理。')
    parts.append('</html>');(root/'实验报告.html').write_text('\n'.join(parts),encoding='utf-8')
    info.update({'formal_elapsed_seconds':round(elapsed,3) if elapsed is not None else None,'runs':runs,'message_count':len(messages),'delivery_count':len(rows),'delivery_acked':len(good),'token_usage':usage,'metrics_count':len(model),'otlp_metric_series':len(model_hist)})
    write_json(root/'实验状态.json',info)

def require_compiler():
    compiler=shutil.which('cc') or shutil.which('gcc')
    def ok():
        if not compiler:return False
        try:return subprocess.run([compiler,'--version'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=30).returncode==0
        except (OSError,subprocess.SubprocessError):return False
    if ok():return compiler
    if sys.platform=='darwin' and shutil.which('xcode-select'):
        emit('[工具] 需要 Apple Command Line Tools，正在启动官方安装；请在系统窗口确认。')
        subprocess.run(['xcode-select','--install'],check=False)
        started=time.monotonic();last=0
        while time.monotonic()-started<1800:
            if ok():return compiler
            if time.monotonic()-last>=15:emit('[工具] 等待系统开发工具安装，已等待 '+clock(time.monotonic()-started));last=time.monotonic()
            time.sleep(3)
    raise ExperimentError('未找到可运行的 C 编译器，请完成 macOS 开发工具安装后重新运行。')

def serve(state):
    server=Server(('127.0.0.1',0),Handler);server.state=state;server.tokens={}
    url=f'http://127.0.0.1:{server.server_address[1]}/'
    for role in ('leader',)+ROLES:
        token=secrets.token_urlsafe(32);server.tokens[token]=role
        state.metrics_endpoints[role]=url+'metrics/'+token
        path=state.repos[role]/'.experiment-build/control.json'
        write_json(path,{'url':url,'token':token,'role':role});path.chmod(0o600)
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
    return server

def probe_telemetry(state):
    emit('[模型] 检查 Codex 是否支持向本机导出模型指标；该步骤不计入正式耗时。')
    args=[state.codex,'--no-daemon','-a','never','exec','--json','--sandbox','read-only','-c',telemetry_config(state.metrics_endpoints['leader']),'-C',str(state.repos['leader'])]
    if state.model:args.extend(['--model',state.model])
    args.append('只回复 OK。')
    out=state.raw/'模型遥测检查.jsonl';err=state.raw/'模型遥测检查.log'
    with out.open('w',encoding='utf-8') as f,err.open('w',encoding='utf-8') as e:
        p=subprocess.Popen(args,stdin=subprocess.DEVNULL,stdout=f,stderr=e,start_new_session=True)
        started=time.monotonic();notice=started
        while p.poll() is None:
            time.sleep(.5);now=time.monotonic()
            if now-started>150:stop_group(p);emit('[模型] 遥测检查超时，将继续实验并标记不可得。');return False
            if now-notice>15:emit('[模型] 正在检查本机遥测，已耗时 '+clock(now-started));notice=now
    kinds=[]
    for line in out.read_text(encoding='utf-8',errors='replace').splitlines():
        try:kinds.append(json.loads(line).get('type'))
        except ValueError:pass
    if p.returncode or 'turn.completed' not in kinds:
        emit('[模型] 当前版本不支持此遥测配置，将保留原始事件；详情见记录/模型遥测检查.log。');return False
    emit('[模型] 遥测配置可用；实际服务端是否返回推理指标由结果决定。');return True

def completion_result(state,checks):
    actual=set(state.procs)-{'leader'}
    unsuccessful=[r for r in ('leader',)+ROLES if r not in state.runs or state.runs[r].get('exit_code')!=0 or state.runs[r].get('terminal_event')!='turn.completed']
    acked={m['sender'] for m in state.messages.values() if m['sender'] in ROLES and m['deliveries'].get('leader',{}).get('client_receive_ns')}
    reported=set()
    for role in ('W1','W2','W3','W4'):
        commits=[x['mono_ns'] for x in state.events if x.get('event')=='git_operation' and x.get('agent')==role and x.get('operation')=='提交工作' and x.get('exit_code')==0]
        if commits and any(m['sender']==role and m.get('service_recv_ns',0)>=max(commits) and m['deliveries'].get('leader',{}).get('client_receive_ns') for m in state.messages.values()):reported.add(role)
    passed=bool(checks) and all(x.get('passed') for x in checks.values())
    ends=[state.runs.get(r,{}).get('end_ns') for r in ('W1','W2','W3','W4')]
    review=False
    if all(isinstance(t,int) for t in ends):
        finish=max(ends)
        review_end=state.runs.get('W5',{}).get('end_ns')
        starts=[m['deliveries'].get('W5',{}).get('client_receive_ns') for m in state.messages.values() if m['sender']=='leader' and m['kind']=='message']
        replies=[m['service_recv_ns'] for m in state.messages.values() if m['sender']=='W5' and m['deliveries'].get('leader',{}).get('client_receive_ns')]
        if isinstance(review_end,int):review=any(isinstance(t,int) and finish<=t<=review_end and any(t<=reply<=review_end for reply in replies) for t in starts)
    topic_ok=any(m.get('sender')=='leader' and m.get('topic')=='download/contract' and 'filename' in m.get('text','').lower() and 'utf-8' in m.get('text','').lower() and sum(bool(d.get('client_receive_ns')) for d in m['deliveries'].values())>=2 for m in state.messages.values())
    missing_reports=sorted(set(('W1','W2','W3','W4'))-reported)
    ok=actual==set(ROLES) and not unsuccessful and acked==set(ROLES) and not missing_reports and passed and review and topic_ok
    detail=('Agent 启动 '+str(len(actual))+'/5；未成功结束 '+str(unsuccessful)+'；未被 Leader 领取回报 '+str(sorted(set(ROLES)-acked))+'；提交后的回报未确认 '+str(missing_reports)+'；Topic 契约投递'+('已确认' if topic_ok else '未确认')+'；W5 最终审查交互'+('已记录' if review else '未确认')+'；功能测试'+('通过' if passed else '未全部通过')+'。')
    return ok,detail

def agent_main(argv):
    parser=argparse.ArgumentParser(description='本次实验内部 Agent 通信客户端')
    parser.add_argument('--agent',action='store_true');parser.add_argument('--control',required=True)
    sub=parser.add_subparsers(dest='action',required=True)
    a=sub.add_parser('send');a.add_argument('--to',required=True);a.add_argument('--text',required=True)
    a=sub.add_parser('publish');a.add_argument('--topic',required=True);a.add_argument('--text',required=True)
    a=sub.add_parser('subscribe');a.add_argument('--topic',required=True)
    a=sub.add_parser('unsubscribe');a.add_argument('--topic',required=True)
    a=sub.add_parser('poll');a.add_argument('--wait',type=float,default=0)
    a=sub.add_parser('spawn');a.add_argument('worker',choices=ROLES);a.add_argument('--text',required=True)
    sub.add_parser('commit')
    a=sub.add_parser('integrate');a.add_argument('worker',choices=ROLES)
    sub.add_parser('continue-integration')
    sub.add_parser('status')
    args=parser.parse_args(argv)
    return bus_client(args.control,args.action,args)

def main():
    base=pathlib.Path.home()/'codex-agent-experiments';mkdir(base)
    runid='browser01-'+dt.datetime.now().strftime('%Y%m%d-%H%M%S')+'-'+secrets.token_hex(3)
    root=mkdir(base/runid);root.chmod(0o700);mkdir(root/'记录');mkdir(root/'测试')
    cache=mkdir(base/'工具缓存');log=root/'准备过程.log'
    info={'status':'未完成','detail':'准备尚未开始','run_id':runid,'application':'Dillo','app_commit':APP_REV,'started_utc':stamp(),'architecture':'独立 Codex CLI 进程 + 实验 Leader 路由','checks':{}}
    state=None;server=None;sampler=None;code=1;formal=False
    try:
        emit('Dillo 浏览器多 Agent 一键实验\n结果目录：'+str(root)+'\n本实验使用独立 Codex Leader 和 5 个 Worker，会消耗账号模型额度。')
        emit('\n【准备 1/4：检查开发工具】')
        if not shutil.which('git'):raise ExperimentError('未找到 Git，请先安装 macOS Command Line Tools。')
        cc=require_compiler();env=os.environ.copy()
        env['PATH']='/opt/homebrew/bin:/usr/local/bin:'+env.get('PATH','')
        codex=ensure_codex(cache,env,log)
        v=subprocess.run([codex,'--version'],capture_output=True,text=True,timeout=30)
        info['codex_version']=v.stdout.strip();info['compiler']=cc
        emit('\n【准备 2/4：复用或下载 Dillo，创建独立 Agent 工作区】')
        repos=prepare_repos(cache,root,log)
        emit('\n【准备 3/4：上游基线测试】')
        info['baseline_cases']=baseline(repos['leader'],cc,log)
        emit('\n【准备 4/4：Codex 登录与模型连接】')
        selected_model=check_auth(codex,repos['leader'],root/'记录');info['model_selection']=selected_model or 'Codex 默认模型'
        env['RUST_LOG']=env.get('RUST_LOG','warn')+',codex_otel=info'
        state=State(root,repos,codex,env,None,cc);state.model=selected_model
        server=serve(state)
        state.telemetry_enabled=probe_telemetry(state);info['otel_local_enabled']=state.telemetry_enabled
        info['host']=host_profile();info['system_before_formal']=system_snapshot()
        emit('\n【正式开发：Leader 分派、5 个 Worker 并发开发】')
        info['detail']='正在进行正式开发。';write_json(root/'实验状态.json',info)
        state.start_ns=time.monotonic_ns()
        try:state.launch('leader',leader_prompt(state))
        except BaseException:
            formal='leader' in state.procs
            if not formal:state.start_ns=0
            raise
        formal=True
        sampler=threading.Thread(target=sample_resources,args=(state,),daemon=True);sampler.start()
        start=time.monotonic();notice=start
        agent_failure=''
        while state.procs['leader'].poll() is None:
            time.sleep(.5);now=time.monotonic()
            if now-start>TIMEOUT:raise ExperimentError('正式开发达到两小时上限；已保留全部日志。')
            failed=[r for r,p in list(state.procs.items()) if r in ROLES and p.poll() not in (None,0)]
            if failed:
                role=failed[0];message=model_error(state.raw/(role+'-events.jsonl'))
                if not message:
                    path=state.raw/(role+'-stderr.log');message=redacted(path.read_text(encoding='utf-8',errors='replace')[-2000:]) if path.exists() else ''
                agent_failure=f'{role} 退出码 {state.procs[role].returncode}：{message or "请查看该 Agent 的事件日志"}'
                emit('[错误] '+agent_failure+'；正在结束本批次并生成报告。');stop_group(state.procs['leader']);break
            if now-notice>=15:
                st=state.status(); running=', '.join(r for r,x in st.items() if x['state']=='running') or '无'
                emit(f'[状态] 正式开发已耗时 {clock(now-start)}；运行中：{running}；消息 {len(state.messages)} 条。')
                notice=now
        # A finished Leader must not leave unattended worker processes behind.
        post_leader_start=time.monotonic()
        still=[r for r,p in state.procs.items() if r!='leader' and p.poll() is None]
        if still:
            emit('[状态] Leader 已退出，等待仍在运行的 Worker 完成，最多 30 秒。')
            until=time.monotonic()+30
            while time.monotonic()<until and any(state.procs[r].poll() is None for r in still):time.sleep(.5)
        still=[r for r,p in state.procs.items() if r!='leader' and p.poll() is None]
        if still:
            for role in still:stop_group(state.procs[role])
            info['detail']='Leader 已结束，但 Worker 尚未完成：'+', '.join(still)
        for watcher in state.watchers:watcher.join(timeout=5)
        info['post_leader_wait_seconds']=round(time.monotonic()-post_leader_start,3)
        emit('\n【正式任务：独立功能和集成验证】')
        verification_start=time.monotonic()
        info['checks']=final_checks(repos['leader'],cc,root,repos)
        info['validation_seconds']=round(time.monotonic()-verification_start,3)
        state.end_ns=time.monotonic_ns()
        success,detail=completion_result(state,info['checks'])
        if success:
            info['status']='核心开发与独立验证完成';info['detail']='已运行独立 Codex 进程和本机中继；完整浏览器 GUI 未验证。';code=0
        else:
            info['status']='未完成';info['detail']=detail+(' '+agent_failure if agent_failure else '');code=1
    except KeyboardInterrupt:
        info['status']='已中断';info['detail']='用户中断，已保留现有日志。';code=130
    except (ExperimentError,OSError,ValueError,subprocess.SubprocessError,tarfile.TarError) as e:
        info['status']='未完成';info['detail']=redacted(e);emit('\n[失败] '+info['detail']);code=1
    finally:
        info['finished_utc']=stamp()
        if state:
            state.stop.set()
            with state.changed:state.changed.notify_all()
            if server:server.shutdown();server.server_close()
            state.close()
            if sampler:sampler.join(timeout=6)
            if formal and not state.end_ns:state.end_ns=time.monotonic_ns()
            try:make_report(state,info)
            except Exception as e:
                info['report_error']=redacted(e);write_json(root/'实验状态.json',info);emit('[报告] 生成报告失败：'+redacted(e))
        else:
            write_json(root/'实验状态.json',info)
            (root/'实验报告.html').write_text('<!doctype html><meta charset="utf-8"><h1>Dillo 多 Agent 实验：未完成</h1><p>'+html.escape(info['detail'])+'</p><p>正式任务尚未开始；请查看准备过程.log 与记录目录。</p>',encoding='utf-8')
        emit('\n实验报告：'+str(root/'实验报告.html'))
        if sys.platform=='darwin':subprocess.run(['open',str(root/'实验报告.html')],check=False)
    return code

if __name__=='__main__':
    try:
        rc=agent_main(sys.argv[1:]) if '--agent' in sys.argv[1:] else main()
    except Exception as e:
        print('运行失败：'+redacted(e),file=sys.stderr);rc=1
    if '--agent' not in sys.argv[1:] and sys.stdin.isatty():
        try:input('\n按回车关闭窗口…')
        except (EOFError,KeyboardInterrupt):pass
    sys.exit(rc)
