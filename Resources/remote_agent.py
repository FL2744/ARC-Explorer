"""ARC-Explorer: one-shot SSH JSON interface; standard library only.

No daemon, credentials, or elevated privileges. Commands run as the SSH user.
"""
import base64
import datetime
import json
import os
from pathlib import Path
import re
import shlex
import stat
import subprocess
import sys
import uuid

MAX_FILE = 8 * 1024 * 1024

def run(argv, timeout=30):
    p = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    if p.returncode:
        raise RuntimeError((p.stderr or p.stdout or 'Command failed')[-16000:].strip())
    return p.stdout

def shell(script, timeout=30):
    return run(['bash', '-lc', script], timeout)

def path(value):
    if not isinstance(value, str) or not value.strip() or '\x00' in value:
        raise ValueError('Choose a nonempty remote path')
    p = Path(value).expanduser()
    if not p.is_absolute():
        raise ValueError('Remote paths must be absolute or start with ~/')
    return p

def token(value, label='value'):
    if not isinstance(value, str) or not re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.:@+-]*', value):
        raise ValueError('Invalid ' + label)
    return value

def jobid(value):
    if not re.fullmatch(r'\d+(?:_[\d]+)?', str(value)):
        raise ValueError('Invalid job ID')
    return str(value)

def capture(label, script):
    try: return {'title': label, 'text': shell(script), 'ok': True}
    except Exception as e: return {'title': label, 'text': str(e), 'ok': False}

def resources(q):
    account=token(q['account'], 'allocation')
    partition=token(q['partition'], 'partition')
    wall=q.get('walltime', '01:00:00')
    if not re.fullmatch(r'(?:\d+-)?\d{1,3}:[0-5]\d:[0-5]\d', wall):
        raise ValueError('Wall time must be HH:MM:SS or D-HH:MM:SS')
    values=[]
    for key, lo, hi, default in [('cpus',1,256,4),('memory',1,2048,16),('gpus',1,8,1)]:
        val=q.get(key,default)
        if type(val) is not int or not lo<=val<=hi: raise ValueError('Invalid '+key)
        values.append(val)
    cpus,memory,gpus=values
    args=['--account='+account,'--partition='+partition,'--time='+wall,'--cpus-per-task='+str(cpus),'--mem='+str(memory)+'G','--nodes=1','--ntasks=1']
    if gpus: args.append('--gres=gpu:'+str(gpus))
    return args

def install_script(q):
    provider=q.get('provider')
    if provider not in ['GitHub','Hugging Face']: raise ValueError('Select GitHub or Hugging Face')
    repo=q.get('repo','')
    if not re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.-]*/[A-Za-z0-9_][A-Za-z0-9_.-]*',repo):
        raise ValueError('Repository must be owner/name')
    revision=q.get('revision','').strip()
    if revision and (revision.startswith('-') or not re.fullmatch(r'[A-Za-z0-9_./-]+',revision) or '..' in revision):
        raise ValueError('Invalid revision')
    dest=path(q.get('destination','')).resolve()
    if dest == Path.home() or dest == Path('/') or len(dest.parts)<3: raise ValueError('Choose a dedicated destination folder')
    base='https://github.com/' if provider=='GitHub' else 'https://huggingface.co/'
    url=base+repo+('.git' if provider=='GitHub' else '')
    sq=shlex.quote
    lines=['set -euo pipefail','export GIT_TERMINAL_PROMPT=0',f'DEST={sq(str(dest))}',f'URL={sq(url)}', 'command -v git >/dev/null']
    if provider=='Hugging Face': lines+=['git lfs version >/dev/null']
    lines += ['mkdir -p "$(dirname "$DEST")"',
        'if [ -e "$DEST" ]; then',
        '  test -d "$DEST/.git" || { echo "Destination exists and is not a Git checkout" >&2; exit 1; }',
        '  test "$(git -C "$DEST" remote get-url origin)" = "$URL" || { echo "Origin does not match requested repository" >&2; exit 1; }',
        '  test -z "$(git -C "$DEST" status --porcelain)" || { echo "Local changes found; update stopped" >&2; exit 1; }',
        '  git -C "$DEST" fetch origin', 'else', '  git clone -- "$URL" "$DEST"', 'fi']
    if revision:
        lines+=['git -C "$DEST" checkout --detach '+sq(revision)]
    else:
        lines+=['git -C "$DEST" pull --ff-only']
    if provider=='Hugging Face': lines+=['git -C "$DEST" lfs pull']
    lines+=['git -C "$DEST" rev-parse HEAD', 'echo "Source ready at $DEST. Review its README before running setup or installing dependencies."']
    return '\n'.join(lines)+'\n'

def submit(q):
    opts=resources(q)
    script=q.get('script','')
    if not isinstance(script,str) or not script.strip() or len(script.encode())>200000:
        raise ValueError('Use a nonempty script under 200 KB')
    workspace=path(q.get('workspace','~/arc-explorer')).resolve()
    if workspace==Path.home() or len(workspace.parts)<3: raise ValueError('Use a dedicated workspace')
    workdir=path(q.get('workdir','~'))
    if not workdir.is_dir(): raise ValueError('Working directory does not exist')
    directory=workspace/'jobs'/str(uuid.uuid4())
    directory.mkdir(parents=True, mode=0o700)
    file=directory/'job.sh'
    file.write_text('#!/bin/bash\nset -euo pipefail\n'+script+'\n')
    file.chmod(0o700)
    jid=shell(shlex.join(['sbatch','--parsable','--job-name=arc-explorer','--chdir='+str(workdir),'--output='+str(directory/'job.log'),'--error='+str(directory/'job.log')]+opts+[str(file)])).strip().split(';')[0]
    jobid(jid)
    record={'job_id':jid,'directory':str(directory),'created_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'kind':q.get('kind','batch')}
    (directory/'job.json').write_text(json.dumps(record))
    return record

import stat, hashlib, tempfile

# Lightweight file operations only; model execution remains in Slurm jobs.
TEXT_LIMIT = 1024 * 1024

def file_path(value):
    if not isinstance(value, str) or not value or '\x00' in value:
        raise ValueError('Enter an absolute path or a path beginning with ~/.')
    path = Path(value).expanduser()
    if not path.is_absolute():
        raise ValueError('Enter an absolute path or a path beginning with ~/.')
    return path

def read_text_file(path):
    # Reject special files before opening (FIFO/device reads could hang).
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode):
        raise ValueError('Open a regular file. Symbolic links and special files are read-only in this editor.')
    if info.st_nlink != 1:
        raise ValueError('Hard-linked files are not supported by this editor.')
    fd = os.open(str(path), os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as f:
        info = os.fstat(f.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise ValueError('This is not an editable regular file.')
        raw = f.read(TEXT_LIMIT + 1)
    if len(raw) > TEXT_LIMIT:
        raise ValueError('The lightweight editor supports files up to 1 MiB.')
    if b'\x00' in raw:
        raise ValueError('Binary files cannot be opened in the text editor.')
    try: text = raw.decode('utf-8')
    except UnicodeDecodeError:
        raise ValueError('The editor supports UTF-8 text files only.')
    revision = hashlib.sha256(raw).hexdigest() + ':' + str(info.st_dev) + ':' + str(info.st_ino) + ':' + str(info.st_mtime_ns)
    return {'path':str(path), 'text':text, 'revision':revision, 'bytes':len(raw)}, info

def file_operation(q):
    op = q['op']; path = file_path(q.get('path', '~'))
    if op == 'files_list':
        path = path.resolve(strict=True)
        entries = []; truncated = False
        with os.scandir(path) as scan:
            for entry in scan:
                if len(entries) >= 5000:
                    truncated = True; break
                try:
                    info = entry.stat(follow_symlinks=False)
                    entries.append({'id':entry.path, 'name':entry.name,
                        'directory':entry.is_dir(), 'link':entry.is_symlink(),
                        'size':info.st_size})
                except OSError: continue
        entries.sort(key=lambda x:(not x['directory'],x['name'].casefold()))
        return {'path':str(path), 'parent':str(path.parent), 'entries':entries, 'truncated':truncated}
    if op == 'files_read':
        return read_text_file(path)[0]
    if op == 'files_save':
        data = q.get('text')
        if not isinstance(data, str): raise ValueError('Missing text.')
        raw = data.encode('utf-8')
        if len(raw) > TEXT_LIMIT or b'\x00' in raw:
            raise ValueError('Save UTF-8 text of at most 1 MiB, without NUL bytes.')
        old, info = read_text_file(path)
        if old['revision'] != q.get('revision'):
            raise ValueError('This file changed on ARC. Your edits are still in the editor. Copy them before reloading the remote file.')
        if not os.access(path, os.W_OK): raise PermissionError('The remote file is not writable.')
        # Preserve shared-file ownership/ACL behavior: decline atomic replacement
        # of files owned by another account or with extended attributes.
        if info.st_uid != os.getuid(): raise PermissionError('Only files owned by your ARC account can be edited.')
        if hasattr(os, 'listxattr') and os.listxattr(path):
            raise ValueError('Files with extended attributes or ACLs are not supported by this editor.')
        fd, temp = tempfile.mkstemp(prefix='.'+path.name+'.affector-', dir=path.parent)
        try:
            with os.fdopen(fd, 'wb') as f:
                os.fchown(f.fileno(), info.st_uid, info.st_gid)
                os.fchmod(f.fileno(), stat.S_IMODE(info.st_mode))
                f.write(raw); f.flush(); os.fsync(f.fileno())
            if read_text_file(path)[0]['revision'] != old['revision']:
                raise ValueError('File changed during save. Your edits have not overwritten it; reload before saving.')
            os.replace(temp, path)
        finally:
            if os.path.exists(temp): os.unlink(temp)
        return read_text_file(path)[0]
    if op == 'files_create':
        name = q.get('name','')
        if not name or name in ('.','..') or '/' in name or '\x00' in name:
            raise ValueError('Enter a filename, without directory separators.')
        dest = path / name
        with dest.open('xb') as f: os.fchmod(f.fileno(), 0o600)
        return read_text_file(dest)[0]
    raise ValueError('Unknown file operation')

def dispatch(q):
    if q.get("op", "").startswith("files_"): return file_operation(q)
    op=q.get('op')
    if op=='probe':
        return {'host':run(['hostname']).strip(),'user':run(['id','-un']).strip(),'home':str(Path.home()),'slurm':shell('sinfo --version').strip()}
    if op=='overview':
        return {'sections':[
            capture('Partitions / availability','sinfo -o "%P|%a|%l|%D|%t|%C|%G"'),
            capture('My allocations','sacctmgr -n -P show assoc where user="$USER" format=Cluster,Account,Partition,QOS'),
            capture('Storage','df -h "$HOME"'),
            capture('Quota','TERM=dumb timeout 15 quota') ]}
    if op=='jobs':
        # Per-user filters avoid exposing or modifying other users' jobs.
        data=shell('squeue -h -u "$USER" -o "%i|%j|%P|%T|%M|%l|%R"')
        rows=[]
        for line in data.splitlines():
            vals=line.split('|',6)
            if len(vals)==7: rows.append(dict(zip(['id','name','partition','state','elapsed','limit','reason'],vals)))
        history=capture('Recent jobs','sacct -X -u "$USER" -S today --format=JobID,JobName,Partition,State,Elapsed,ExitCode -P')
        return {'jobs':rows,'history':history['text']}
    if op in ['job_detail','cancel']:
        jid=jobid(q['id'])
        if op=='job_detail':
            return {'text':shell('scontrol show job '+shlex.quote(jid))}
        owner=shell('squeue -h -j '+shlex.quote(jid)+' -o %u').strip().splitlines()
        me=run(['id','-un']).strip()
        if not owner or any(x!=me for x in owner): raise ValueError('Can only cancel your own queued or running jobs')
        shell('scancel '+shlex.quote(jid))
        return {'message':'Cancellation requested for '+jid}
    if op=='files':
        directory=path(q.get('path','~'))
        rows=[]
        with os.scandir(directory) as entries:
            for index,e in enumerate(entries):
                if index>=5000: break
                try:
                    st=e.stat(follow_symlinks=False)
                    rows.append({'id':str(directory/e.name),'name':e.name,'directory':e.is_dir(),'link':e.is_symlink(),'size':st.st_size,'modified':datetime.datetime.fromtimestamp(st.st_mtime).isoformat(timespec='seconds')})
                except OSError: pass
        return {'path':str(directory),'parent':str(directory.parent),'files':sorted(rows,key=lambda x:(not x['directory'],x['name'].lower())),'limit':5000}
    if op in ['read','download']:
        p=path(q['path'])
        if not p.is_file(): raise ValueError('Select a regular file')
        if op=='read':
            with p.open('rb') as f: data=f.read(128000)
            if b'\x00' in data: raise ValueError('Binary file: use Download')
            return {'text':data.decode('utf-8',errors='replace'),'truncated':p.stat().st_size>128000}
        if p.stat().st_size>MAX_FILE: raise ValueError('Use Open OnDemand or SFTP for files over 8 MB')
        return {'data':base64.b64encode(p.read_bytes()).decode()}
    if op=='upload':
        p=path(q['path']); data=base64.b64decode(q['data'],validate=True)
        if len(data)>MAX_FILE: raise ValueError('Use Open OnDemand or SFTP for files over 8 MB')
        # Exclusive creation: never overwrite a file or follow an existing symlink.
        with p.open('xb') as f: f.write(data)
        return {'message':'Uploaded '+str(p)}
    if op=='mkdir':
        p=path(q['path']); p.mkdir(mode=0o700)
        return {'message':'Created '+str(p)}
    if op=='modules': return {'text':shell('module -t avail 2>&1',60)}
    if op=='allocation':
        account=token(q['account'],'allocation')
        start=datetime.date.fromisoformat(q['start'])
        end=datetime.date.fromisoformat(q['end'])
        if start>end: raise ValueError('Start date must precede end date')
        end_exclusive=end+datetime.timedelta(days=1)
        return {'sections':[
            capture('ARC allocation usage · service-defined period', 'TERM=dumb getusage --account '+shlex.quote(account)),
            capture('ARC allocation and storage balances', 'TERM=dumb quota'),
            capture('Account jobs · selected dates', shlex.join(['sacct','-X','-A',account,'-S',str(start),'-E',str(end_exclusive),'-P','--format=JobID,User,Account,Partition,State,Elapsed,AllocTRES%100'])),
            capture('Slurm fair-share usage · not remaining balance',shlex.join(['sshare','-A',account,'-l']))]}
    if op=='install_preview': return {'script':install_script(q)}
    if op=='submit': return submit(q)
    raise ValueError('Unknown operation')

if __name__=='__main__':
    os.umask(0o077)
    try:
        request=json.load(sys.stdin)
        print(json.dumps({'ok':True,'result':dispatch(request)},allow_nan=False))
    except Exception as e:
        print(json.dumps({'ok':False,'error':str(e)}))
        sys.exit(1)
