#!/bin/bash
# 双击运行。测试实现随脚本附带，无需下载其他项目文件。
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"
set -u
TEMP_DIR=""
finish() {
  [ -z "$TEMP_DIR" ] || rm -rf "$TEMP_DIR"
  echo
  read -r -p '按回车关闭窗口…' _ || true
}
trap finish EXIT
fail() { echo; echo "无法继续：$1"; exit 1; }

echo '===== Codex 多 Agent 一键实验 ====='
echo '将引导你选择项目、检查登录并开始测试。'
echo
command -v git >/dev/null 2>&1 || fail '未找到 Git。请先安装 macOS 命令行开发工具，再重新双击。'
if ! command -v python3 >/dev/null 2>&1; then
  echo '需要 Python 3.9 或更新版本。将打开 Python 下载页面；安装后重新双击本文件。'
  command -v open >/dev/null 2>&1 && open 'https://www.python.org/downloads/macos/'
  exit 1
fi
python3 -c 'import sys; sys.exit(sys.version_info < (3,9))' || fail 'Python 版本过旧，请安装 Python 3.9 或更新版本。'

DATA_DIR="$HOME/Library/Application Support/Codex多Agent实验"
mkdir -p "$DATA_DIR" || fail '无法创建实验工具目录。'
export PATH="$DATA_DIR/node/bin:$PATH"
if ! command -v codex >/dev/null 2>&1; then
  echo '未找到 Codex CLI。将尝试通过 npm 安装到当前用户的实验工具目录。'
  if ! command -v npm >/dev/null 2>&1; then
    echo '需要先安装 Node.js（含 npm）。将打开 Node.js 下载页面；安装后重新双击本文件。'
    command -v open >/dev/null 2>&1 && open 'https://nodejs.org/en/download'
    exit 1
  fi
  npm install --prefix "$DATA_DIR/node" @openai/codex || fail 'Codex 安装失败，请检查网络及 npm 后重新运行。'
  command -v codex >/dev/null 2>&1 || fail '安装后仍找不到 codex。'
fi

echo '正在检查 Codex 登录状态…'
if ! codex login status; then
  echo '请按照 Codex 的提示在浏览器完成登录；不会要求你在本工具中输入或保存密钥。'
  codex login || fail '登录未完成，请检查终端提示后重试。'
  codex login status || fail '未能确认登录状态，请检查 Codex 配置。'
fi

echo
echo '请选择用于测试的 Git 项目文件夹。'
if command -v osascript >/dev/null 2>&1; then
  PROJECT=$(osascript -e 'POSIX path of (choose folder with prompt "选择要进行多 Agent 测试的 Git 项目")') || fail '未选择项目。'
else
  read -r -p '请输入 Git 项目路径：' PROJECT || fail '未输入项目。'
fi
[ -d "$PROJECT" ] || fail '项目目录不存在。'
git -C "$PROJECT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail '所选目录不是 Git 项目。'

echo
echo '选择测试方式：'
echo '  1. 只读分析（推荐，不修改项目）'
echo '  2. 开发任务（允许修改所选项目，请使用项目副本）'
read -r -p '输入 1 或 2，直接回车选择 1：' CHOICE || fail '无法读取选择。'
case "$CHOICE" in
  ''|1) MODE=readonly; TIMEOUT=1800 ;;
  2) MODE=write; TIMEOUT=3600 ;;
  *) fail '请选择 1 或 2。' ;;
esac

echo '正在准备报告组件，首次运行需要联网，可能需要几分钟…'
if [ ! -x "$DATA_DIR/venv/bin/python" ]; then
  python3 -m venv "$DATA_DIR/venv" || fail '无法创建 Python 环境，请检查 Python venv 组件。'
fi
if ! "$DATA_DIR/venv/bin/python" -c 'import docx' >/dev/null 2>&1; then
  "$DATA_DIR/venv/bin/python" -m pip install 'python-docx>=1.1,<2' || fail '报告组件安装失败，请检查网络后重试。'
fi
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/codex-agent-kit.XXXXXXXX") || fail '无法创建临时目录。'
awk 'found {print} /^# __PYTHON_PAYLOAD__$/ {found=1}' "$0" > "$TEMP_DIR/agent_experiment.py" || fail '无法读取脚本内容。'
cat > "$TEMP_DIR/smoke.txt" <<'PROMPT'
请明确使用多智能体并行完成本次只读分析。启动 3 个子 Agent：A 分析当前 Git 项目的主要目录和功能模块；B 分析如何安装依赖、运行项目及测试；C 寻找模块之间的关键接口及可能的集成风险。所有子 Agent 不修改文件、不安装依赖、不执行会改变项目的命令。由主 Agent 等待并综合它们的结果，列出各自负责内容，并给出适合后续多人并行开发的一个功能建议。
PROMPT
cat > "$TEMP_DIR/development.txt" <<'PROMPT'
请使用多个子 Agent 协作，为当前项目增加一个与现有项目实际功能相符的小型功能。先检查项目结构和现有规范，选择可以涉及两个代码模块和测试的合理需求，然后再实施。主 Agent 负责协调需求、接口、集成测试以及问题修复；至少启动三个子 Agent 分别负责不同模块的实现、相关测试或只读审查，按实际项目结构划分任务，并避免同时修改同一文件。让相关 Agent 汇报接口定义、修改文件与测试结果；出现错误时协调定位和修复。最后给出变更、测试结果、未解决问题。不得推送、发布、删除仓库数据或修改凭据。
PROMPT
if [ "$MODE" = readonly ]; then PROMPT_FILE="$TEMP_DIR/smoke.txt"; else PROMPT_FILE="$TEMP_DIR/development.txt"; fi
mkdir -p "$HOME/codex-agent-experiments" || fail '无法创建结果目录。'
OUTPUT=$(mktemp -d "$HOME/codex-agent-experiments/experiment-XXXXXXXX") || fail '无法创建结果目录。'
rmdir "$OUTPUT" || fail '无法准备结果目录。'
echo
echo "开始测试，结果目录：$OUTPUT"
echo '运行可能需要较长时间，完成前请不要关闭此窗口。'
"$DATA_DIR/venv/bin/python" "$TEMP_DIR/agent_experiment.py" --project "$PROJECT" --mode "$MODE" --prompt "$PROMPT_FILE" --timeout "$TIMEOUT" --output "$OUTPUT"
RESULT=$?
echo
if [ "$RESULT" -eq 0 ]; then
  echo '程序运行结束。请打开 实验统计报告.docx，确认关联到子 Agent 会话且识别到消息。'
else
  echo "测试未正常完成（退出码 $RESULT）。请查看结果目录中的 codex-stderr.log 和 实验信息.json。"
fi
if [ -d "$OUTPUT" ] && command -v open >/dev/null 2>&1; then open "$OUTPUT" || true; fi
exit "$RESULT"
# __PYTHON_PAYLOAD__
#!/usr/bin/env python3
"""Run local Codex and conservatively extract observable collaboration records."""
from __future__ import annotations
import argparse, collections, csv, datetime as dt, json, os, pathlib, re, shutil, signal, subprocess, sys, threading, time
from typing import Any

HERE = pathlib.Path(__file__).resolve().parent
OUT_FIELDS = ['时间','发送方','接收方','事件','消息内容','UTF8字节','状态','来源文件','行号','说明']
COLLAB = {'spawn_agent','send_message','send_input','followup_task','wait_agent','wait','close_agent','interrupt_agent','list_agents'}
SEND = {'spawn_agent','send_message','send_input','followup_task'}

def json_obj(v: Any) -> Any:
    if isinstance(v, str):
        try: return json.loads(v)
        except (ValueError, TypeError): return v
    return v

def lines(path):
    try:
        with path.open(encoding='utf-8') as f:
            for n, line in enumerate(f, 1):
                try:
                    v=json.loads(line)
                    if isinstance(v, dict): yield n,v
                except (ValueError, UnicodeError): continue
    except (OSError, UnicodeError): return

def meta(path):
    for _, obj in lines(path):
        if obj.get('type')=='session_meta':
            p=obj.get('payload') or {}; src=p.get('source') or {}
            if not isinstance(src,dict): src={}
            sub=src.get('subagent') or {}; sub=sub if isinstance(sub,dict) else {}
            spawn=sub.get('thread_spawn') or {}; spawn=spawn if isinstance(spawn,dict) else {}
            return {'id':str(p.get('id') or ''), 'parent':str(spawn.get('parent_thread_id') or p.get('parent_thread_id') or ''), 'name':str(spawn.get('agent_path') or ''), 'path':path}
    return None

def collect_sessions(home, outdir, root_id, start):
    dest=outdir/'sessions'; dest.mkdir(exist_ok=True)
    if not root_id: return [], '事件流中没有 root thread ID，未复制会话文件。'
    base=home/'sessions'; found={}
    if not base.exists(): return [], f'未找到会话目录：{base}'
    for p in base.rglob('*.jsonl'):
        try:
            if p.stat().st_mtime < start-300: continue
            m=meta(p)
            if m and m['id']: found[m['id']]=m
        except OSError: pass
    selected={root_id} if root_id in found else set()
    while True:
        expanded=selected | {i for i,m in found.items() if m['parent'] in selected}
        if expanded==selected: break
        selected=expanded
    result=[]
    for i in sorted(selected):
        m=found[i]; target=dest/(re.sub(r'[^a-zA-Z0-9_-]','_',i)+'.jsonl')
        shutil.copy2(m['path'],target); m=dict(m); m['path']=target; result.append(m)
    return result, ('已按 root ID 和父子 ID 关联会话。' if root_id in found else '未找到 root 的会话记录；未按时间猜测归属。')

def csvsafe(v):
    s=str(v or '')
    return "'"+s if s.lstrip().startswith(('=','+','-','@')) else s

def sample_processes(pid, path, stop):
    """Sample root process and descendants; not a per-agent attribution."""
    with path.open('w',encoding='utf-8',newline='') as f:
        w=csv.writer(f); w.writerow(['timestamp_utc','pid','ppid','cpu_percent','rss_kib','command'])
        while not stop.is_set():
            try:
                result=subprocess.run(['ps','-axo','pid=,ppid=,%cpu=,rss=,comm='],capture_output=True,text=True,timeout=5)
                processes={}
                for ln in result.stdout.splitlines():
                    parts=ln.strip().split(None,4)
                    if len(parts)==5 and parts[0].isdigit() and parts[1].isdigit(): processes[int(parts[0])]=parts
                selected={pid}
                while True:
                    more=selected | {p for p,v in processes.items() if int(v[1]) in selected}
                    if selected==more: break
                    selected=more
                now=dt.datetime.now(dt.timezone.utc).isoformat()
                for p in sorted(selected):
                    if p in processes: w.writerow([now,*processes[p]])
                f.flush()
            except (OSError,subprocess.SubprocessError): pass
            stop.wait(2)

def resource_stats(path):
    groups=collections.defaultdict(lambda:[0,0.0,0])
    try:
        with path.open(encoding='utf-8',newline='') as f:
            for r in csv.DictReader(f):
                g=groups[r['timestamp_utc']]; g[0]+=1; g[1]+=float(r['cpu_percent']); g[2]+=int(r['rss_kib'])
    except (OSError,KeyError,ValueError): return {}
    if not groups: return {}
    return {'sample_times':len(groups),'max_visible_processes':max(v[0] for v in groups.values()),'max_cpu_percent_sum':round(max(v[1] for v in groups.values()),1),'max_rss_kib_sum':max(v[2] for v in groups.values())}

def parse_sessions(sessions,root_id):
    rows=[]; diagnostics=[]
    names={m['id']:(m['name'] or ('/root' if m['id']==root_id else m['id'])) for m in sessions}
    for m in sessions:
        owner=names.get(m['id'],m['id']); calls={}; payloads=[]
        for n,obj in lines(m['path']):
            p=obj.get('payload');
            if obj.get('type')!='response_item' or not isinstance(p,dict): continue
            kind=p.get('type'); name=str(p.get('name') or '').split('.')[-1]
            if kind in ('function_call','custom_tool_call') and name in COLLAB:
                args=json_obj(p.get('arguments') or p.get('input') or {})
                if not isinstance(args,dict): args={}
                callid=str(p.get('call_id') or p.get('id') or '')
                if callid: calls[callid]=(name,args,n,obj.get('timestamp',''))
                if name in SEND:
                    content=args.get('message') or args.get('prompt') or args.get('text') or ''
                    target=args.get('target') or args.get('agent_id') or args.get('task_name') or args.get('recipient') or ''
                    if isinstance(content,str) and content:
                        rows.append({'时间':obj.get('timestamp',''),'发送方':owner,'接收方':str(target) or '未知','事件':name,'消息内容':content,'UTF8字节':len(content.encode('utf-8')),'状态':'调用记录，送达待核对','来源文件':m['path'].name,'行号':n,'说明':'按工具参数提取消息正文；工具调用不等于确认送达。'})
                    else:
                        diagnostics.append(f"{m['path'].name}:{n} {name} 未能读取明文消息参数")
            elif kind in ('function_call_output','custom_tool_call_output'):
                cid=str(p.get('call_id') or '')
                if cid in calls: payloads.append((n,obj,calls[cid]))
        for n,obj,(tool,args,call_line,ts) in payloads:
            if tool not in ('wait_agent','wait','close_agent'): continue
            p=obj['payload']; raw=p.get('output'); v=json_obj(raw)
            # Only count a result with an explicit completed status and string content.
            if isinstance(v,dict):
                statuses=v.get('status') or v.get('statuses') or {}
                if isinstance(statuses,dict):
                    for sender, state in statuses.items():
                        body=state.get('completed') if isinstance(state,dict) else None
                        if isinstance(body,str) and body:
                            rows.append({'时间':obj.get('timestamp',''),'发送方':names.get(str(sender),str(sender)),'接收方':owner,'事件':'已返回结果','消息内容':body,'UTF8字节':len(body.encode('utf-8')),'状态':'等待结果中可见','来源文件':m['path'].name,'行号':n,'说明':'仅统计明确 completed 文本；与子会话的重复通知不再累加。'})
    rows.sort(key=lambda r:(str(r['时间']),str(r['来源文件']),int(r['行号'])))
    return rows,diagnostics

def parse_latencies(sessions):
    """Pair tool calls and outputs within one session, never across sessions."""
    rows=[]
    for session in sessions:
        calls={}
        for number, obj in lines(session['path']):
            p=obj.get('payload')
            if obj.get('type')!='response_item' or not isinstance(p,dict): continue
            kind=p.get('type'); cid=str(p.get('call_id') or p.get('id') or '')
            name=str(p.get('name') or '').split('.')[-1]
            if kind in ('function_call','custom_tool_call') and name in COLLAB and cid:
                calls[cid]=(name,obj.get('timestamp',''),number)
            elif kind in ('function_call_output','custom_tool_call_output') and cid in calls:
                tool,started,start_line=calls.pop(cid)
                ended=obj.get('timestamp',''); duration=''; status='ok'
                try:
                    a=dt.datetime.fromisoformat(started.replace('Z','+00:00'))
                    b=dt.datetime.fromisoformat(ended.replace('Z','+00:00'))
                    if a.tzinfo is None or b.tzinfo is None: raise ValueError('timezone missing')
                    seconds=(b-a).total_seconds()
                    if seconds < 0: raise ValueError('negative duration')
                    duration=round(seconds*1000,3)
                except (ValueError,TypeError,AttributeError): status='invalid_timestamp'
                rows.append({'session_id':session['id'],'tool':tool,'call_id':cid,'started_utc':started,'ended_utc':ended,'duration_ms':duration,'measurement_status':status,'source_file':session['path'].name,'call_line':start_line,'output_line':number})
        for cid,(tool,started,start_line) in calls.items():
            rows.append({'session_id':session['id'],'tool':tool,'call_id':cid,'started_utc':started,'ended_utc':'','duration_ms':'','measurement_status':'missing_output','source_file':session['path'].name,'call_line':start_line,'output_line':''})
    return rows

def create_docx(path, manifest, rows, diagnostics):
    from docx import Document
    from docx.shared import Pt, Inches, RGBColor
    from docx.oxml.ns import qn
    from docx.enum.text import WD_BREAK
    d=Document(); sec=d.sections[0]; sec.top_margin=Inches(.7); sec.bottom_margin=Inches(.7)
    style=d.styles['Normal']; style.font.name='Microsoft YaHei'; style.font.size=Pt(10.5); style._element.rPr.rFonts.set(qn('w:eastAsia'),'Microsoft YaHei')
    for style_name in ('Title','Heading 1','Heading 2'):
        s=d.styles[style_name]; s.font.name='Microsoft YaHei'; s.font.color.rgb=RGBColor(0,0,0); s._element.get_or_add_rPr().get_or_add_rFonts().set(qn('w:eastAsia'),'Microsoft YaHei')
    title_style=d.styles['Title']._element
    for border in title_style.xpath('./w:pPr/w:pBdr'):
        border.getparent().remove(border)
    d.add_heading('Codex 多智能体通信实验报告',0)
    d.add_paragraph('实验运行：'+manifest.get('run_id','未提供'))
    d.add_heading('一 实验结论与采集状态',level=1)
    n_agents=manifest.get('session_count',0); count=len(rows); size=sum(int(x['UTF8字节']) for x in rows)
    d.add_paragraph(f'关联到 {n_agents} 个会话文件；提取到 {count} 条可识别的协作消息正文，共 {size:,} UTF-8 字节。该结果仅覆盖本版本解析器识别到的记录，完整性尚需人工核对。')
    d.add_paragraph('子 Agent 会话数为 '+str(max(0,n_agents-1))+'；会话数不代表独立进程或容器数。')
    if not rows: d.add_paragraph('本次没有提取到可识别消息。请检查 root 会话是否保存、是否实际调用了子 Agent、原始字段是否变化；不能据此判断真实消息量为零。')
    d.add_paragraph('采集状态：'+manifest.get('session_note','未提供'))
    d.add_paragraph('Codex 退出状态：'+str(manifest.get('exit_code','未提供'))+'；超时：'+str(manifest.get('timed_out',False)))
    d.add_paragraph('运行时进程采样见进程资源.csv；采样对象是 Codex 进程及可见子进程，不能归因为每个 Agent，采样值也不包含不可见的容器或远端模型服务。')
    d.add_paragraph('调用耗时.csv 按同一会话内的工具调用 ID 配对时间戳；可计算的调用数：'+str(manifest.get('latency_paired_calls',0))+'。耗时包括工具执行和等待，不代表网络或消息传输延迟；缺失或无效时间戳不计为零。')
    rs=manifest.get('resources') or {}
    if rs:
        d.add_paragraph(f"采样 {rs['sample_times']} 次；最多同时观察到 {rs['max_visible_processes']} 个进程；进程 CPU% 总和峰值 {rs['max_cpu_percent_sum']}%，RSS 总和峰值约 {rs['max_rss_kib_sum']/1024:.1f} MiB。RSS 相加可能重复计算共享内存。")
    else: d.add_paragraph('本次没有可用的进程资源采样。')
    d.add_heading('二 消息类型统计',level=1)
    sums=collections.defaultdict(lambda:[0,0])
    for row in rows: sums[row['事件']][0]+=1; sums[row['事件']][1]+=row['UTF8字节']
    if sums:
        table=d.add_table(rows=1,cols=3); table.style='Light Shading Accent 1'
        for cell,text in zip(table.rows[0].cells,['事件','条数','正文 UTF-8 字节']): cell.text=text
        for k,(n,b) in sorted(sums.items()):
            for cell,text in zip(table.add_row().cells,[str(k),str(n),f'{b:,}']): cell.text=text
    else: d.add_paragraph('没有符合当前提取规则的记录。')
    d.add_heading('三 消息明细摘录',level=1)
    if not rows: d.add_paragraph('无。')
    for i,r in enumerate(rows[:30],1):
        d.add_paragraph(f"{i}. {r['发送方']} → {r['接收方']}  |  {r['事件']}  |  {r['UTF8字节']} 字节",style='Heading 2')
        safe_text=re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', '', r['消息内容'])
        body=d.add_paragraph(safe_text[:600]+('…（完整内容见 CSV）' if len(safe_text)>600 else ''))
        body.paragraph_format.keep_with_next=True
        d.add_paragraph(f"来源：{r['来源文件']} 第 {r['行号']} 行；{r['状态']}。")
    if len(rows)>30: d.add_paragraph(f'报告展示前 30 条，共 {len(rows)} 条；完整明细见消息明细.csv。')
    d.add_heading('四 口径与核对',level=1)
    d.add_paragraph('任务下发按协作工具的明文参数提取。调用记录不保证成功送达；无法解析收件人时显示未知。')
    d.add_paragraph('结果返回只统计等待工具输出中明确标记完成的文本。子会话终态、通知和公开事件流不叠加计数；其他格式可能漏计。')
    d.add_paragraph('字节数为消息正文的 UTF-8 编码长度，不等于网络字节数。读取文件、模型请求、继承上下文和协议开销均未包含。')
    d.add_paragraph('事件用途按工具类型初分；具体消息目的需要人工阅读。')
    if diagnostics:
        d.add_paragraph('待核对记录：'+str(len(diagnostics))+' 条。示例：'+'；'.join(diagnostics[:3]))
    d.save(path)

def analyze(outdir,manifest,sessions):
    rows,diag=parse_sessions(sessions,manifest.get('root_thread_id',''))
    latency=parse_latencies(sessions)
    with (outdir/'调用耗时.csv').open('w',encoding='utf-8-sig',newline='') as f:
        fields=['session_id','tool','call_id','started_utc','ended_utc','duration_ms','measurement_status','source_file','call_line','output_line']
        w=csv.DictWriter(f,fieldnames=fields); w.writeheader()
        for row in latency: w.writerow({k:(csvsafe(v) if isinstance(v,str) else v) for k,v in row.items()})
    manifest['latency_paired_calls']=sum(r['measurement_status']=='ok' for r in latency)
    manifest['resources']=resource_stats(outdir/'进程资源.csv')
    with (outdir/'消息明细.csv').open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=OUT_FIELDS); w.writeheader()
        for row in rows: w.writerow({k:(csvsafe(v) if isinstance(v,str) else v) for k,v in row.items()})
    (outdir/'待核对.txt').write_text('\n'.join(diag) or '无解析器诊断。请仍抽查原始会话记录。',encoding='utf-8')
    manifest['recognized_messages']=len(rows); manifest['recognized_body_bytes']=sum(x['UTF8字节'] for x in rows); manifest['diagnostics']=len(diag)
    (outdir/'实验信息.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    create_docx(outdir/'实验统计报告.docx',manifest,rows,diag)
    return rows

def main():
    ap=argparse.ArgumentParser(description='Codex 本地多 Agent 通信实验；默认只读分析。')
    ap.add_argument('--project',default='.',help='目标 Git 项目目录；默认当前目录')
    ap.add_argument('--prompt',default=str(HERE/'prompts/smoke.txt'),help='任务提示词文本文件')
    ap.add_argument('--mode',choices=['readonly','write'],default='readonly',help='只读或允许工作区修改')
    ap.add_argument('--timeout',type=int,default=1800,help='最多等待秒数；默认 1800')
    ap.add_argument('--model',help='可选 Codex 模型名；不指定时使用现有配置')
    ap.add_argument('--output',help='本次输出目录；默认 ~/codex-agent-experiments 下新建')
    ap.add_argument('--analyze',help='重新分析既有运行目录，不再调用 Codex')
    args=ap.parse_args()
    if args.analyze:
        out=pathlib.Path(args.analyze).expanduser().resolve(); manifest=json.loads((out/'实验信息.json').read_text(encoding='utf-8'))
        sessions=[m for p in (out/'sessions').glob('*.jsonl') if (m:=meta(p))]
        analyze(out,manifest,sessions); print('已重新生成报告：',out); return
    if args.timeout<1: ap.error('--timeout 必须大于零')
    project=pathlib.Path(args.project).expanduser().resolve(); prompt=pathlib.Path(args.prompt).expanduser().resolve()
    if not project.is_dir(): ap.error('项目目录不存在')
    if not prompt.is_file(): ap.error('提示词文件不存在')
    if not shutil.which('codex'): ap.error('未找到 codex；请先安装并登录 Codex CLI')
    if subprocess.run(['git','-C',str(project),'rev-parse','--is-inside-work-tree'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode: ap.error('目标目录不是 Git 工作区')
    run_id=dt.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    out=pathlib.Path(args.output).expanduser().resolve() if args.output else pathlib.Path.home()/'codex-agent-experiments'/run_id
    out.mkdir(parents=True,exist_ok=False)
    # Do not copy auth or environment variables into experiment output.
    prompt_text=prompt.read_text(encoding='utf-8'); (out/'使用的任务.txt').write_text(prompt_text,encoding='utf-8')
    head=subprocess.run(['git','-C',str(project),'rev-parse','HEAD'],capture_output=True,text=True).stdout.strip()
    ver=subprocess.run(['codex','--version'],capture_output=True,text=True).stdout.strip()
    cmd=['codex','exec','--json','--enable','multi_agent','--sandbox','read-only' if args.mode=='readonly' else 'workspace-write','-C',str(project)]
    if args.model: cmd.extend(['--model',args.model])
    cmd.append('-')
    print('任务已启动，记录保存到：',out,flush=True)
    print('运行结束或达到超时后生成报告；Codex 的详细过程写入原始文件。',flush=True)
    start=time.time(); monotonic_start=time.monotonic(); timed_out=False
    with (out/'codex-events.jsonl').open('w',encoding='utf-8') as stdout, (out/'codex-stderr.log').open('w',encoding='utf-8') as stderr:
        try:
            proc=subprocess.Popen(cmd,stdout=stdout,stderr=stderr,stdin=subprocess.PIPE,start_new_session=True,text=True)
            stop=threading.Event()
            sampler=threading.Thread(target=sample_processes,args=(proc.pid,out/'进程资源.csv',stop),daemon=True); sampler.start()
            try:
                proc.communicate(input=prompt_text,timeout=args.timeout); code=proc.returncode
            except subprocess.TimeoutExpired:
                timed_out=True; code=124
                try: os.killpg(proc.pid,signal.SIGTERM)
                except ProcessLookupError: pass
                try: proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    try: os.killpg(proc.pid,signal.SIGKILL)
                    except ProcessLookupError: pass
                    proc.wait()
            finally: stop.set(); sampler.join(timeout=6)
        except OSError as e: code=127; stderr.write(str(e))
    elapsed_seconds=round(time.monotonic()-monotonic_start,3)
    finished=dt.datetime.now(dt.timezone.utc).isoformat()
    root=''
    for _,obj in lines(out/'codex-events.jsonl'):
        if obj.get('type')=='thread.started': root=str(obj.get('thread_id') or ''); break
    codex_home=pathlib.Path(os.environ.get('CODEX_HOME') or pathlib.Path.home()/'.codex').expanduser()
    sessions,note=collect_sessions(codex_home,out,root,start)
    manifest={'run_id':run_id,'project':str(project),'git_head':head,'codex_version':ver,'model_override':args.model,'mode':args.mode,'started_utc':dt.datetime.fromtimestamp(start,dt.timezone.utc).isoformat(),'finished_utc':finished,'elapsed_seconds':elapsed_seconds,'exit_code':code,'timed_out':timed_out,'root_thread_id':root,'session_count':len(sessions),'session_note':note}
    rows=analyze(out,manifest,sessions)
    print(f'报告已生成：{out}/实验统计报告.docx')
    print(f'消息明细：{out}/消息明细.csv；识别 {len(rows)} 条。')
    if code: print(f'Codex 退出码 {code}，请查看 codex-stderr.log 和实验报告。',file=sys.stderr)
    return code
if __name__=='__main__': sys.exit(main())
