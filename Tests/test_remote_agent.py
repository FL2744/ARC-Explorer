import base64
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('agent',Path(__file__).parents[1]/'Resources/remote_agent.py')
a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
class RemoteTests(unittest.TestCase):
 def request(self,**kwargs):
  return dict(account='will_taggart_mcll',partition='a100_normal_q',cpus=2,memory=4,gpus=1,walltime='00:02:00',**kwargs)
 def test_gpu_required(self):
  q=self.request();q['gpus']=0
  with self.assertRaises(ValueError):a.resources(q)
 def test_resource_request(self):
  self.assertIn('--gres=gpu:1',a.resources(self.request()))
 def test_bad_resource_values(self):
  for field,value in [('account','x;rm -rf /'),('partition','-x'),('walltime','00:99:00'),('cpus',True),('memory',0),('gpus',9)]:
   q=self.request();q[field]=value
   with self.subTest(field=field),self.assertRaises(ValueError):a.resources(q)
 def test_arbitrary_login_command_not_supported(self):
  with self.assertRaises(ValueError):a.dispatch({'op':'command','command':'python expensive.py'})
 def test_download_upload_roundtrip(self):
  with tempfile.TemporaryDirectory() as d:
   p=str(Path(d)/'file.txt');data=base64.b64encode(b'hello').decode()
   a.dispatch({'op':'upload','path':p,'data':data})
   self.assertEqual(a.dispatch({'op':'download','path':p})['data'],data)
   with self.assertRaises(FileExistsError):a.dispatch({'op':'upload','path':p,'data':data})
 def test_upload_symlink_no_overwrite(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'target';p.write_text('original');link=Path(d)/'link';link.symlink_to(p)
   with self.assertRaises(FileExistsError):a.dispatch({'op':'upload','path':str(link),'data':base64.b64encode(b'changed').decode()})
   self.assertEqual(p.read_text(),'original')
 def test_preview_limit(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'large';p.write_text('x'*140000)
   result=a.dispatch({'op':'read','path':str(p)})
   self.assertEqual(len(result['text']),128000);self.assertTrue(result['truncated'])
 def test_binary_preview(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'binary';p.write_bytes(b'abc\x00')
   with self.assertRaises(ValueError):a.dispatch({'op':'read','path':str(p)})
 def test_install_injection(self):
  for repo in ['--evil','foo/bar;touch x','https://github.com/a/b','a/../b']:
   with self.assertRaises(ValueError):a.install_script({'provider':'GitHub','repo':repo,'destination':'~/arc-explorer/project'})
 def test_install_clean_checkout(self):
  s=a.install_script({'provider':'GitHub','repo':'FL2744/AFFECTOR','destination':'~/arc-explorer/project'})
  for expected in ['--ff-only','status --porcelain','remote get-url origin','GIT_TERMINAL_PROMPT=0']:self.assertIn(expected,s)
  self.assertNotIn('pip install',s)
 def test_hf_requires_lfs(self):
  s=a.install_script({'provider':'Hugging Face','repo':'will-taggart/AFFECTOR-ARC','destination':'~/arc-explorer/project'})
  self.assertIn('git lfs version',s);self.assertIn('lfs pull',s)
 def test_install_home_rejected(self):
  with self.assertRaises(ValueError):a.install_script({'provider':'GitHub','repo':'a/b','destination':'~'})
 def test_cancellation_ownership(self):
  with patch.object(a,'shell',return_value='someone_else\n') as sh,patch.object(a,'run',return_value='me\n'):
   with self.assertRaises(ValueError):a.dispatch({'op':'cancel','id':'123'})
   self.assertEqual(sh.call_count,1)
 def test_cancellation_my_job(self):
  with patch.object(a,'shell',side_effect=['me\n','']) as sh,patch.object(a,'run',return_value='me\n'):
   a.dispatch({'op':'cancel','id':'123'})
   self.assertEqual(sh.call_args.args[0],'scancel 123')
 def test_invalid_job_id(self):
  with self.assertRaises(ValueError):a.dispatch({'op':'job_detail','id':'123;id'})
 def test_allocation_period(self):
  with patch.object(a,'capture',side_effect=lambda title,cmd:{'title':title,'text':cmd,'ok':True}):
   r=a.dispatch({'op':'allocation','account':'test','start':'2026-11-01','end':'2026-11-13'})
   self.assertIn('getusage --account test',r['sections'][0]['text'])
   self.assertIn('2026-11-14',r['sections'][2]['text'])
 def test_bad_period(self):
  with self.assertRaises(ValueError):a.dispatch({'op':'allocation','account':'test','start':'2026-11-13','end':'2026-11-01'})
 def test_submit_uses_sbatch_not_login_execution(self):
  with tempfile.TemporaryDirectory() as d,patch.object(a,'shell',return_value='12345\n') as sh:
   q=self.request(script='nvidia-smi',workspace=d+'/workspace',workdir=d)
   result=a.submit(q)
   self.assertEqual(result['job_id'],'12345');cmd=sh.call_args.args[0]
   self.assertTrue(cmd.startswith('sbatch '));self.assertIn('--gres=gpu:1',cmd)
   self.assertIn('nvidia-smi',(Path(result['directory'])/'job.sh').read_text())
   self.assertNotIn('nvidia-smi',cmd)
 def test_partial_monitor_failure_preserved(self):
  with patch.object(a,'shell',side_effect=RuntimeError('Unavailable')):
   result=a.capture('Quota','quota');self.assertFalse(result['ok']);self.assertEqual(result['text'],'Unavailable')
if __name__=='__main__':unittest.main()
