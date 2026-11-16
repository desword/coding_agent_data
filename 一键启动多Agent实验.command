#!/usr/bin/env python3
"""Standalone Android/Codex experiment. Run by double-click or python3."""
from __future__ import annotations
import base64, collections, contextlib, csv, datetime as dt, html, json, math, os, pathlib, re, shutil, signal, socket, statistics, subprocess, sys, tempfile, threading, time, urllib.parse, webbrowser, zlib

APP_URL = 'https://github.com/android/nowinandroid.git'
APP_REV = 'a49ed253d75e61a2b6ab80a8da677b57437b08eb'
FLOW_URL = 'https://github.com/ChrisThoma/android-bug-priority-tree.git'
FLOW_REV = '3c473b9c3e7620df2fc4ee830921e8512036416a'
APP_ID = 'com.google.samples.apps.nowinandroid.demo.debug'
RUNNER = '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'

class SetupError(Exception): pass

def command(argv, *, cwd=None, env=None, logfile=None, timeout=None, stdin=None, interactive=False):
    print('\n$', ' '.join(str(x) for x in argv), flush=True)
    if interactive:
        p = subprocess.run(argv, cwd=cwd, env=env, timeout=timeout, input=stdin, text=True)
    else:
        with open(logfile, 'a', encoding='utf-8') as log:
            log.write('\n$ ' + ' '.join(map(str, argv)) + '\n'); log.flush()
            p = subprocess.run(argv, cwd=cwd, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=timeout, input=stdin, text=True)
    if p.returncode:
        raise SetupError(f'{argv[0]} 返回 {p.returncode}' + (f'，详情见 {logfile}' if logfile else ''))
    return p

def locate_sdk():
    candidates = [os.environ.get('ANDROID_SDK_ROOT'), os.environ.get('ANDROID_HOME'), str(pathlib.Path.home()/'Library/Android/sdk'), str(pathlib.Path.home()/'Android/Sdk')]
    for x in candidates:
        if x and pathlib.Path(x).is_dir(): return pathlib.Path(x).expanduser().resolve()
    raise SetupError('未找到 Android SDK。请安装 Android Studio、SDK 和 Command-line Tools 后重新运行；不要在聊天中提供密钥。')

def tool(sdk, *paths):
    for path in paths:
        p = sdk/path
        if p.is_file() and os.access(p, os.X_OK): return str(p)
    raise SetupError(f'Android SDK 缺少 {paths[0]}；请在 Android Studio 的 SDK Manager 安装对应组件。')

def java21():
    env = os.environ.copy()
    if sys.platform == 'darwin' and pathlib.Path('/usr/libexec/java_home').exists():
        p = subprocess.run(['/usr/libexec/java_home','-v','21'], capture_output=True, text=True)
        if p.returncode == 0 and p.stdout.strip():
            env['JAVA_HOME'] = p.stdout.strip(); env['PATH'] = str(pathlib.Path(env['JAVA_HOME'])/'bin') + os.pathsep + env.get('PATH','')
    java = shutil.which('java', path=env.get('PATH'))
    if not java: raise SetupError('未找到 JDK 21；请安装后重试。')
    p = subprocess.run([java, '-version'],capture_output=True,text=True)
    match = re.search(r'version "(\d+)', p.stderr + p.stdout)
    if p.returncode or not match or int(match.group(1)) < 21: raise SetupError('需要 JDK 21 或更高版本。')
    return env

def ports(count):
    # Probe both emulator console and adb port; the emulator itself performs the final bind.
    answer=[]
    for p in range(5554, 5680, 2):
        sockets=[]
        try:
            for n in (p,p+1):
                s=socket.socket(); sockets.append(s); s.bind(('127.0.0.1',n))
            answer.append(p)
        except OSError: pass
        finally:
            for s in sockets: s.close()
        if len(answer)==count: return answer
    raise SetupError('找不到两个空闲模拟器端口。')

def booted(adb, serial, env, proc, seconds=360):
    end=time.monotonic()+seconds
    while time.monotonic()<end:
        if proc.poll() is not None: raise SetupError(f'{serial} 模拟器提前退出，请查看其日志。')
        p=subprocess.run([adb,'-s',serial,'shell','getprop','sys.boot_completed'],env=env,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True,timeout=10)
        if p.returncode==0 and p.stdout.strip()=='1': return
        time.sleep(3)
    raise SetupError(f'{serial} 在 {seconds} 秒内未完成启动。')

def timestamp(value):
    try:
        d=dt.datetime.fromisoformat(value.replace('Z','+00:00'))
        return d if d.tzinfo else None
    except (ValueError,TypeError,AttributeError): return None

def parse_telemetry(path):
    """Conservative parser: only send/receive with the same explicit communication_id."""
    ansi=re.compile(r'\x1b\[[0-9;]*m'); records=collections.defaultdict(lambda: {'send': [], 'receive': []})
    if not path.exists(): return []
    def val(line,key):
        m=re.search(r'\b'+re.escape(key)+r'\s*[=:]\s*(?:"([^"\n]*)"|([^\s,}\]]+))',line)
        return (m.group(1) or m.group(2)) if m else ''
    for n,raw in enumerate(path.read_text(encoding='utf-8',errors='replace').splitlines(),1):
        line=ansi.sub('',raw)
        if 'agent_communication' not in line: continue
        cid=val(line,'communication_id'); state=val(line,'state')
        t=re.search(r'\b\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?(?:Z|[+-]\d\d:\d\d)',line)
        if cid and state in ('send','receive'):
            records[cid][state].append({'time':t.group(0) if t else '', 'line':n, 'sender':val(line,'sender_thread_id'),'receiver':val(line,'receiver_thread_id'),'kind':val(line,'kind')})
    result=[]
    for cid,pair in records.items():
        a=pair['send']; b=pair['receive']; status='ok'; ms=''
        if len(a)!=1 or len(b)!=1: status='missing_or_duplicate_event'
        else:
            ta=timestamp(a[0]['time']); tb=timestamp(b[0]['time'])
            if ta is None or tb is None or tb<ta: status='invalid_timestamp'
            else: ms=round((tb-ta).total_seconds()*1000,3)
        one=a[0] if a else {}; two=b[0] if b else {}
        result.append({'communication_id':cid,'kind':one.get('kind',''),'sender_thread_id':one.get('sender',''),'receiver_thread_id':one.get('receiver',''),'send_utc':one.get('time',''),'receive_utc':two.get('time',''),'delivery_ms':ms,'status':status,'send_line':one.get('line',''),'receive_line':two.get('line','')})
    return result

def write_csv(path,fields,rows):
    with path.open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields); w.writeheader()
        for row in rows:
            w.writerow({k:("'"+v if isinstance(v,str) and v.lstrip().startswith(('=','+','-','@')) else v) for k,v in row.items()})

def stats(values):
    values=sorted(values)
    if not values: return '无可配对样本'
    percentile=lambda p: values[max(0,math.ceil(len(values)*p)-1)]
    result=f'样本 {len(values)}，中位数 {statistics.median(values):.3f} ms，最大 {values[-1]:.3f} ms'
    if len(values)>=20: result+=f'，P95 {percentile(.95):.3f} ms'
    if len(values)>=100: result+=f'，P99 {percentile(.99):.3f} ms'
    return result

def report(root, info):
    event_dir=root/'记录'; diag=[]; counts=collections.defaultdict(lambda:[0,0]); directions=collections.defaultdict(lambda:[0,0]); examples=[]; call_times=collections.defaultdict(list)
    try:
        with (event_dir/'消息明细.csv').open(encoding='utf-8-sig',newline='') as f:
            for row in csv.DictReader(f):
                key=row.get('事件','未知'); counts[key][0]+=1
                try:
                    size=int(row['UTF8字节']); counts[key][1]+=size
                    sender=row.get('发送方',''); receiver=row.get('接收方','')
                    if sender=='/root' and receiver not in ('/root','未知',''): direction='Leader → Worker'
                    elif receiver=='/root' and sender not in ('/root','未知',''): direction='Worker → Leader'
                    else: direction='方向未知或其他'
                    directions[direction][0]+=1; directions[direction][1]+=size
                    if len(examples)<12: examples.append((direction,key,row.get('消息内容','')[:300],row.get('来源文件',''),row.get('行号','')))
                except (KeyError,ValueError): diag.append('某条消息的字节数不可解析。')
    except OSError: diag.append('消息明细不存在：未能运行或分析 Codex。')
    try:
        with (event_dir/'调用耗时.csv').open(encoding='utf-8-sig',newline='') as f:
            for row in csv.DictReader(f):
                if row.get('measurement_status')=='ok':
                    try: call_times[row['tool']].append(float(row['duration_ms']))
                    except (KeyError,ValueError): pass
    except OSError: pass
    tele=parse_telemetry(event_dir/'codex-stderr.log')
    fields=['communication_id','kind','sender_thread_id','receiver_thread_id','send_utc','receive_utc','delivery_ms','status','send_line','receive_line']
    write_csv(root/'投递时间明细.csv',fields,tele)
    delivery=collections.defaultdict(list)
    for row in tele:
        if row['status']=='ok': delivery[row['kind'] or 'unknown'].append(row['delivery_ms'])
    info['telemetry_events_matched']=sum(len(v) for v in delivery.values())
    info['recognized_messages_by_tool']={k:{'count':v[0],'body_utf8_bytes':v[1]} for k,v in counts.items()}
    info['recognized_messages_by_direction']={k:{'count':v[0],'body_utf8_bytes':v[1]} for k,v in directions.items()}
    (root/'实验状态.json').write_text(json.dumps(info,ensure_ascii=False,indent=2),encoding='utf-8')
    e=html.escape
    parts=['<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>Android 多 Agent 实验报告</title><style>body{font:16px/1.65 -apple-system,BlinkMacSystemFont,sans-serif;max-width:1000px;margin:40px auto;padding:0 20px;color:#1f2937}table{border-collapse:collapse;width:100%}td,th{border:1px solid #ddd;padding:8px;text-align:left}code{background:#f1f5f9;padding:2px 4px}</style><h1>Android 多 Agent 实验报告</h1>']
    parts.append('<p>运行状态：<b>'+e(str(info.get('status','未知')))+'</b>。 '+e(str(info.get('detail','')))+'</p>')
    parts.append('<p>应用和基线：Now in Android <code>'+APP_REV+'</code>；公开工作流：Android Bug Priority Tree <code>'+FLOW_REV+'</code>。应用与流程的组合、设备槽位属于本实验配置。</p>')
    parts.append('<h2>阶段耗时</h2><table><tr><th>阶段</th><th>秒</th><th>状态</th></tr>')
    for p in info.get('phases',[]): parts.append('<tr><td>'+e(p['name'])+'</td><td>'+str(p['seconds'])+'</td><td>'+e(p['status'])+'</td></tr>')
    parts.append('</table><h2>可识别消息正文</h2><p>按工具调用参数及支持格式的完成结果提取；调用不保证送达，未识别记录不等于零。明细包含发送方、接收方和来源行。自动通知、继承上下文、日志不支持的格式可能遗漏。</p><table><tr><th>事件</th><th>条数</th><th>正文 UTF-8 字节</th></tr>')
    for k,(n,b) in sorted(counts.items()): parts.append(f'<tr><td>{e(k)}</td><td>{n}</td><td>{b}</td></tr>')
    if not counts: parts.append('<tr><td colspan="3">没有可识别记录；不能据此判断真实通信量为零。</td></tr>')
    parts.append('</table><h3>通信方向与内容摘录</h3><p>仅在会话明确标识 /root 和对端时归类，无法判断的保留为未知；正文 UTF-8 字节不是网络流量字节，不包含协议开销、模型请求、文件内容和共享上下文。</p><table><tr><th>方向</th><th>条数</th><th>正文 UTF-8 字节</th></tr>')
    for k,(n,b) in sorted(directions.items()): parts.append(f'<tr><td>{e(k)}</td><td>{n}</td><td>{b}</td></tr>')
    if not directions: parts.append('<tr><td colspan="3">没有可分类的消息。</td></tr>')
    parts.append('</table><p>下列内容仅为前 12 条可识别记录的截取，具体用途须结合原始上下文人工判断。</p><table><tr><th>方向 / 事件</th><th>消息摘录</th><th>原始记录</th></tr>')
    for direction,kind,body,source,line in examples: parts.append('<tr><td>'+e(direction+' / '+kind)+'</td><td>'+e(body)+'</td><td>'+e(source+':'+str(line))+'</td></tr>')
    if not examples: parts.append('<tr><td colspan="3">无可展示消息。</td></tr>')
    parts.append('</table><h2>延迟拆分</h2><p>以下为同一会话内工具调用到其返回的时间差；wait 是等待工作结果，通常包括 Agent 工作、模型与排队时间。它们不是网络延迟。</p><table><tr><th>工具</th><th>统计</th></tr>')
    for k,v in sorted(call_times.items()): parts.append('<tr><td>'+e(k)+'</td><td>'+e(stats(v))+'</td></tr>')
    if not call_times: parts.append('<tr><td colspan="2">无可配对的工具调用时间。</td></tr>')
    parts.append('</table><h3>发送到接收事件</h3><p>仅在 Codex 的原始诊断中出现同一通信 ID 的唯一 send 和 receive、且时间有效时配对；时间包含本地排队与调度，不等于网络传输或应用端完整处理。日志版本可能不输出这些事件。</p><table><tr><th>类型</th><th>统计</th></tr>')
    for k,v in sorted(delivery.items()): parts.append('<tr><td>'+e(k)+'</td><td>'+e(stats(v))+'</td></tr>')
    if not delivery: parts.append('<tr><td colspan="2">当前未获得可配对投递事件，无法判断实际投递耗时。</td></tr>')
    parts.append('</table><h2>瓶颈判断</h2><p>本报告不会把模型推理时间、Worker 执行时间或 wait 耗时归因于通信。缺少完整投递时间、跨路径对照与足够样本时，无法判断 Leader–Worker 通信是否为主要瓶颈。模拟器资源采样是设备槽位级，不等于 Agent 或远端模型独占资源。</p>')
    parts.append('<h2>设备与核对</h2><p>本次仅当两个模拟器都启动、安装 APK 并通过非零 Android 测试后才开始 Codex。Agent 使用指定设备仍需逐条核对会话、测试日志与证据，设备启动不证明任务完成。入口、设备数据、失败及未完成内容见实验状态与安装日志。</p>')
    parts.append('<p>原始会话和报告可能包含源代码、截图或敏感信息。查看 <code>记录/消息明细.csv</code>、<code>记录/调用耗时.csv</code>、<code>投递时间明细.csv</code>、<code>记录/codex-stderr.log</code>、<code>设备资源.csv</code> 及原始会话核对。'+e(' '.join(diag))+'</p></html>')
    (root/'实验报告.html').write_text('\n'.join(parts),encoding='utf-8')

def sample_devices(procs,path,stop):
    with path.open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.writer(f); w.writerow(['utc','slot','pid','cpu_percent','rss_kib'])
        while not stop.is_set():
            now=dt.datetime.now(dt.timezone.utc).isoformat()
            for slot,p in procs:
                if p.poll() is not None: continue
                x=subprocess.run(['ps','-p',str(p.pid),'-o','%cpu=,rss='],capture_output=True,text=True)
                vals=x.stdout.split()
                if len(vals)>=2: w.writerow([now,slot,p.pid,vals[0],vals[1]])
            f.flush(); stop.wait(2)

def main():
    if sys.version_info < (3,9): raise SetupError('需要 Python 3.9 或更新版本。')
    root=pathlib.Path.home()/'codex-agent-experiments'/('android01-'+dt.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    root.mkdir(parents=True,exist_ok=False); print('本次实验目录：',root,flush=True)
    log=root/'准备过程.log'; info={'status':'准备中','app_url':APP_URL,'app_commit':APP_REV,'workflow_url':FLOW_URL,'workflow_commit':FLOW_REV,'phases':[],'devices':[],'started_utc':dt.datetime.now(dt.timezone.utc).isoformat()}
    processes=[]; files=[]; stop=threading.Event(); sampler=None; code=1
    @contextlib.contextmanager
    def phase(name):
        print('\n【'+name+'】',flush=True); start=time.monotonic(); item={'name':name,'seconds':0,'status':'进行中'}; info['phases'].append(item)
        try: yield
        except BaseException:
            item['status']='失败或中断'; raise
        else: item['status']='完成'
        finally: item['seconds']=round(time.monotonic()-start,3)
    try:
        with phase('检查工具与登录'):
            if sys.platform=='darwin': os.environ['PATH']='/opt/homebrew/bin:/usr/local/bin:'+os.environ.get('PATH','')
            for name in ('git','python3','node','npm'):
                if not shutil.which(name): raise SetupError(f'缺少 {name}；请安装 Git、Python 3 和 Node.js 20 或更高版本后重试。')
            version=subprocess.run(['node','--version'],capture_output=True,text=True).stdout.strip()
            m=re.match(r'v(\d+)',version)
            if not m or int(m.group(1))<20: raise SetupError('设备操作工具需要 Node.js 20 或更高版本。')
            image_tool='sips' if sys.platform=='darwin' else 'magick'
            if not shutil.which(image_tool): raise SetupError(f'缺少截图缩放工具 {image_tool}；请安装 ImageMagick 或使用系统自带 sips。')
            env=java21(); env['npm_config_cache']=str(root/'npm缓存')
            if not shutil.which('codex',path=env.get('PATH')):
                print('正在本次实验目录安装 Codex CLI。',flush=True)
                command(['npm','install','--prefix',str(root/'codex工具'),'--no-audit','--no-fund','@openai/codex'],env=env,logfile=log,timeout=900)
                env['PATH']=str(root/'codex工具/node_modules/.bin')+os.pathsep+env['PATH']
                os.environ['PATH']=env['PATH']
            sdk=locate_sdk(); env['ANDROID_HOME']=str(sdk); env['ANDROID_SDK_ROOT']=str(sdk)
            adb=tool(sdk,'platform-tools/adb'); emulator=tool(sdk,'emulator/emulator'); sdkmanager=tool(sdk,'cmdline-tools/latest/bin/sdkmanager'); avdmanager=tool(sdk,'cmdline-tools/latest/bin/avdmanager')
            if subprocess.run(['codex','login','status'],env=env).returncode:
                print('请按 Codex 提示完成浏览器登录。',flush=True)
                command(['codex','login'],env=env,interactive=True)
                command(['codex','login','status'],env=env,interactive=True)
            info['codex_version']=subprocess.run(['codex','--version'],env=env,capture_output=True,text=True).stdout.strip()
            venv=root/'工具环境'; command([sys.executable,'-m','venv',str(venv)],logfile=log)
            py=venv/'bin/python'; command([str(py),'-m','pip','install','python-docx>=1.1,<2'],logfile=log,env=env,timeout=600)
        with phase('准备设备操作服务'):
            command(['npm','install','--prefix',str(root/'设备工具'),'--no-audit','--no-fund','@mobilenext/mobile-mcp@1.0.17'],env=env,logfile=log,timeout=900)
            mcp=root/'设备工具/node_modules/.bin/mcp-server-mobile'
            if not mcp.is_file(): raise SetupError('设备操作服务安装后缺少可执行入口。')
            env['ANDROID_EXPERIMENT_MCP_COMMAND']=str(mcp)
            info['device_tool']='@mobilenext/mobile-mcp@1.0.17'
        with phase('准备 Android SDK 与两个模拟器'):
            abi='arm64-v8a' if os.uname().machine.lower() in ('arm64','aarch64') else 'x86_64'
            image='system-images;android-34;google_apis;'+abi
            if not (sdk/'platforms/android-36').is_dir() or not (sdk/'system-images/android-34/google_apis'/abi).is_dir():
                print('将使用 Android SDK Manager 安装平台 36 和 API 34 模拟器镜像；如出现许可协议，请在此窗口阅读并选择。',flush=True)
                command([sdkmanager,'--install','platforms;android-36',image],env=env,interactive=True,timeout=1800)
            avdhome=root/'设备数据'; avdhome.mkdir(); env['ANDROID_AVD_HOME']=str(avdhome); env['ANDROID_USER_HOME']=str(root/'android用户数据'); pathlib.Path(env['ANDROID_USER_HOME']).mkdir()
            command([adb,'start-server'],env=env,logfile=log,timeout=30)
            for idx,p in enumerate(ports(2)):
                name=f'research_{root.name.replace("-", "_")}_{idx+1}'; serial=f'emulator-{p}'
                command([avdmanager,'create','avd','-n',name,'-k',image],env=env,logfile=log,stdin='no\n',timeout=90)
                fh=(root/f'模拟器{idx+1}.log').open('w',encoding='utf-8'); files.append(fh)
                proc=subprocess.Popen([emulator,'-avd',name,'-port',str(p),'-no-window','-no-audio','-no-boot-anim','-no-snapshot-save'],env=env,stdout=fh,stderr=subprocess.STDOUT,start_new_session=True)
                processes.append((serial,proc)); info['devices'].append({'slot':idx+1,'avd':name,'serial':serial,'pid':proc.pid})
            sampler=threading.Thread(target=sample_devices,args=(processes,root/'设备资源.csv',stop),daemon=True); sampler.start()
            for serial,proc in processes: booted(adb,serial,env,proc)
        with phase('下载固定应用和公开工作流'):
            project=root/'应用'; flow=root/'公开工作流'
            for url,path,rev in ((APP_URL,project,APP_REV),(FLOW_URL,flow,FLOW_REV)):
                command(['git','clone','--filter=blob:none','--depth','1','--no-checkout',url,str(path)],logfile=log,timeout=900)
                command(['git','fetch','--depth','1','origin',rev],cwd=path,logfile=log,timeout=300)
                command(['git','checkout','--detach',rev],cwd=path,logfile=log,timeout=120)
                got=subprocess.check_output(['git','rev-parse','HEAD'],cwd=path,text=True).strip()
                if got != rev: raise SetupError('检出的 Git 版本与固定版本不一致。')
            skills=project/'.agents/skills'; skills.mkdir(parents=True,exist_ok=True)
            shutil.copytree(flow/'skills/android-bug-priority-tree',skills/'android-bug-priority-tree')
            # Existing project checkout is an isolated experiment copy.
            env['GRADLE_USER_HOME']=str(root/'Gradle缓存')
        with phase('构建应用和设备测试'):
            command(['./gradlew',':app:assembleDemoDebug',':app:assembleDemoDebugAndroidTest','--no-daemon'],cwd=project,env=env,logfile=log,timeout=2700)
            app_apks=list((project/'app/build/outputs/apk/demo/debug').glob('*.apk'))
            test_apks=list((project/'app/build/outputs/apk/androidTest/demo/debug').glob('*.apk'))
            if len(app_apks)!=1 or len(test_apks)!=1: raise SetupError(f'APK 数量不符合预期：应用 {len(app_apks)}，测试 {len(test_apks)}。')
            for serial,_ in processes:
                for apk in (app_apks[0],test_apks[0]): command([adb,'-s',serial,'install','-r',str(apk)],env=env,logfile=log,timeout=180)
                testlog=root/(serial+'-基线测试.log')
                with testlog.open('w',encoding='utf-8') as f:
                    p=subprocess.run([adb,'-s',serial,'shell','am','instrument','-w',APP_ID+'.test/com.google.samples.apps.nowinandroid.core.testing.NiaTestRunner'],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=900)
                text=testlog.read_text(encoding='utf-8',errors='replace')
                match=re.search(r'OK\s*\(\s*(\d+)\s+tests?\s*\)',text)
                if p.returncode or not match or int(match.group(1))<1 or re.search(r'FAILURES!!!|INSTRUMENTATION_FAILED|INSTRUMENTATION_ABORTED',text):
                    raise SetupError(f'{serial} 的基线设备测试未验证成功，请查看 {testlog}。')
                info['devices'][int(serial==processes[1][0])]['baseline_tests']=int(match.group(1))
        with phase('运行真实 Codex 多 Agent'):
            serials=[p[0] for p in processes]
            prompt=f'''请使用原生多 Agent 工具，按仓库内 $android-bug-priority-tree 公开工作流测试并修复当前 Now in Android demoDebug 应用。项目是隔离副本。\n先阅读项目 AGENTS.md 与该 skill。你是 Leader，负责规划、分派、结果收集、集成与汇报。先建立用户旅程地图；并行启动两个设备测试 Worker，分别负责 For You、Interests / Bookmarks 的真实用户路径，每个 Worker 必须获取以下互不重叠的设备槽位之一：{serials[0]}、{serials[1]}。每个涉及设备的子 Agent 指令必须写明唯一 serial，所有 adb 操作显式使用 adb -s SERIAL；严禁两个并发 Worker 操作同一设备，后续确认、修复和独立验证按空闲槽位排队。Worker 必须在自己的模拟器执行真实交互或设备测试、提供命令与结果、对应设备 serial、问题及证据路径；未执行必须标记未执行，不能伪造。测试需用 demo 的本地数据，不访问真实生产服务，不使用个人账号。\n遵循公开工作流：报告候选、独立确认；仅在发现且确认真实缺陷时分派修复，修复须带回归测试，集成后由不同 Worker 独立复验。无缺陷时如实报告，禁止人为制造缺陷或为通信量填充消息。所有 Worker 需要清楚报告任务、消息和状态；Leader 汇总命令、通过失败数量、代码更改、设备证据和限制。不推送或发布。当前目录为实验副本，允许本地修改与工作流所需的本地提交。\n'''
            (root/'本次任务.txt').write_text(prompt,encoding='utf-8')
            runner=root/'runner.py'
            source=zlib.decompress(base64.b64decode(RUNNER)).decode('utf-8')
            needle="    cmd.append('-')"
            addition="    if os.environ.get('ANDROID_EXPERIMENT_MCP_COMMAND'):\n        cmd.extend(['-c', 'mcp_servers.mobile-mcp.command=' + json.dumps(os.environ['ANDROID_EXPERIMENT_MCP_COMMAND']), '-c', 'sandbox_workspace_write.network_access=true'])\n"
            if source.count(needle)!=1: raise SetupError('内置采集器配置入口不匹配。')
            runner.write_text(source.replace(needle,addition+needle),encoding='utf-8')
            env['RUST_LOG']=(env.get('RUST_LOG','error')+',codex_otel.agent_communication=info')
            env['PATH']=str(sdk/'platform-tools')+os.pathsep+str(sdk/'emulator')+os.pathsep+env['PATH']
            p=subprocess.run([str(py),str(runner),'--project',str(project),'--mode','write','--timeout','7200','--prompt',str(root/'本次任务.txt'),'--output',str(root/'记录')],env=env)
            info['codex_exit_code']=p.returncode
            if p.returncode: raise SetupError(f'Codex 未成功完成（退出码 {p.returncode}）；请查看 记录/codex-stderr.log。')
            meta=json.loads((root/'记录/实验信息.json').read_text(encoding='utf-8'))
            info['session_count']=meta.get('session_count',0); info['recognized_messages']=meta.get('recognized_messages',0)
            if info['session_count']<3 or info['recognized_messages']<1:
                raise SetupError('未关联到至少两个子会话或未识别到协作消息；不能判定多 Agent 测试完成，请检查原始会话。')
            info['status']='Codex 已结束，待人工核对设备使用和 Agent 结果'; code=0
    except KeyboardInterrupt:
        info['status']='用户中断'; info['detail']='实验中断；保留已产生的日志。'; code=130
    except (SetupError, OSError, subprocess.SubprocessError, ValueError) as e:
        info['status']='未完成'; info['detail']=str(e); print('\n未完成：',e,flush=True); code=1
    finally:
        stop.set()
        if sampler: sampler.join(timeout=5)
        for serial,proc in processes:
            if proc.poll() is None:
                try: os.killpg(proc.pid,signal.SIGTERM)
                except ProcessLookupError: pass
        for serial,proc in processes:
            try: proc.wait(timeout=8)
            except subprocess.TimeoutExpired:
                try: os.killpg(proc.pid,signal.SIGKILL)
                except ProcessLookupError: pass
                proc.wait()
        for f in files: f.close()
        info['finished_utc']=dt.datetime.now(dt.timezone.utc).isoformat()
        report(root,info)
        print('\n实验报告：',root/'实验报告.html',flush=True)
        if sys.platform=='darwin': subprocess.run(['open',str(root/'实验报告.html')],check=False)
    return code

if __name__=='__main__':
    try: rc=main()
    except Exception as exc:
        print('启动失败：',exc,file=sys.stderr); rc=1
    if sys.stdin.isatty():
        try: input('\n按回车关闭窗口…')
        except (EOFError,KeyboardInterrupt): pass
    sys.exit(rc)
