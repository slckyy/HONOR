import pytest
from honor_media.runtime import MediaRuntimeConfig,assert_c01_safe

def test_cpu_first():assert_c01_safe(MediaRuntimeConfig())
def test_gpu_disabled():
    with pytest.raises(ValueError):assert_c01_safe(MediaRuntimeConfig(gpu_provider='runpod'))
