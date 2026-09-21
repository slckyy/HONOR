from dataclasses import dataclass
@dataclass(frozen=True)
class MediaRuntimeConfig:
    ffmpeg_bin:str='/usr/bin/ffmpeg';ffprobe_bin:str='/usr/bin/ffprobe';render_concurrency:int=1;gpu_provider:str='disabled'
def assert_c01_safe(config:MediaRuntimeConfig):
    if config.render_concurrency!=1:raise ValueError('Month-1 CPU render concurrency is frozen at 1')
    if config.gpu_provider!='disabled':raise ValueError('GPU adapter is disabled in C01/Month-1 baseline')
