import importlib.util, os, stat, tempfile, unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('files_agent',Path(__file__).resolve().parents[1]/'Resources/remote_agent.py')
a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)

class FileTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
  self.path=self.root/"a file's 中文.txt";self.raw=b'\xef\xbb\xbfHello\r\nworld\r\n';self.path.write_bytes(self.raw);self.path.chmod(0o640)
 def tearDown(self):self.tmp.cleanup()
 def call(self,op,path=None,**kw):return a.dispatch(dict(op='files_'+op,path=str(path or self.path),**kw))
 def test_round_trip_preserves_unicode_bom_crlf_and_permissions(self):
  doc=self.call('read');self.assertEqual(doc['text'].encode(),self.raw)
  self.call('save',text=doc['text']+'中文\r\n',revision=doc['revision'])
  self.assertEqual(self.path.read_bytes(),self.raw+'中文\r\n'.encode());self.assertEqual(stat.S_IMODE(self.path.stat().st_mode),0o640)
 def test_conflict_preserves_remote(self):
  doc=self.call('read');self.path.write_text('external edit')
  with self.assertRaisesRegex(ValueError,'changed'):self.call('save',text='my edit',revision=doc['revision'])
  self.assertEqual(self.path.read_text(),'external edit')
 def test_conflict_during_save_preserves_remote_and_cleans_temp(self):
  from unittest.mock import patch
  doc=self.call('read');original=a.read_text_file;calls=[]
  def read(path):
   calls.append(1)
   if len(calls)==2:path.write_text('concurrent edit')
   return original(path)
  with patch.object(a,'read_text_file',side_effect=read):
   with self.assertRaisesRegex(ValueError,'changed'):self.call('save',text='mine',revision=doc['revision'])
  self.assertEqual(self.path.read_text(),'concurrent edit');self.assertEqual(len(list(self.root.iterdir())),1)
 def test_create_never_overwrites(self):
  with self.assertRaises(FileExistsError):self.call('create',self.root,name=self.path.name)
  self.assertEqual(self.path.read_bytes(),self.raw)
  doc=self.call('create',self.root,name='new.txt');self.assertEqual(doc['text'],'');self.assertEqual(stat.S_IMODE(Path(doc['path']).stat().st_mode),0o600)
 def test_invalid_names(self):
  for name in ['../escape','/tmp/no','..','']:
   with self.assertRaises(ValueError):self.call('create',self.root,name=name)
 def test_binary_large_and_non_utf8_rejected(self):
  for raw in [b'hi\x00',b'\xff',b'x'*(a.TEXT_LIMIT+1)]:
   self.path.write_bytes(raw)
   with self.assertRaises(ValueError):self.call('read')
 def test_symlink_hardlink_fifo_rejected(self):
  link=self.root/'link';link.symlink_to(self.path)
  with self.assertRaises(ValueError):self.call('read',link)
  fifo=self.root/'fifo';os.mkfifo(fifo)
  with self.assertRaises(ValueError):self.call('read',fifo)
  hard=self.root/'hard';os.link(self.path,hard)
  with self.assertRaises(ValueError):self.call('read',hard)
 def test_list_folders_hidden_and_links(self):
  (self.root/'folder').mkdir();(self.root/'.hidden').touch();(self.root/'link').symlink_to(self.path)
  d=self.call('list',self.root);self.assertEqual(d['entries'][0]['name'],'folder');self.assertIn('.hidden',[x['name'] for x in d['entries']]);self.assertTrue(next(x for x in d['entries'] if x['name']=='link')['link'])
 def test_relative_paths_rejected(self):
  with self.assertRaises(ValueError):self.call('list',Path('relative'))
