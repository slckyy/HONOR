from honor_api.storage import LocalStorage,safe_key
import pytest

def test_local_roundtrip(tmp_path):
    s=LocalStorage(str(tmp_path));k=safe_key('uploads/','a/b.bin');m=s.put(k,b'abc','application/octet-stream');assert s.get(k)==b'abc';assert m.sha256=='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';s.delete(k)
def test_prefix_restricted():
    with pytest.raises(ValueError):safe_key('arbitrary/','x')
