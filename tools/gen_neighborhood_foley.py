"""Original synthesized foley, deterministic 22.05kHz PCM. No third-party audio.
Quiet physical cues; these are not recordings or generated human speech.
"""
from pathlib import Path
import wave
import numpy as np

RATE=22050
ROOT=Path(__file__).resolve().parents[1]/'assets'/'sounds'/'neighborhood'
ROOT.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(19)

def save(name,x):
    x=np.asarray(x); x=x/(max(abs(x))+.001)*.55
    with wave.open(str(ROOT/(name+'.wav')),'wb') as out:
        out.setparams((1,2,RATE,0,'NONE','not compressed'))
        out.writeframes((x*32767).astype('<i2').tobytes())

def noise(n):
    # Spectrally softened, periodic air noise for a seamless fan loop.
    f=np.fft.rfftfreq(n,1/RATE)
    return np.fft.irfft(np.fft.rfft(rng.normal(size=n))/(1+(f/1700)**2),n)

t=np.arange(RATE*4)/RATE
save('fan', .16*np.sin(2*np.pi*100*t)+.06*np.sin(2*np.pi*200*t)+.28*noise(len(t))*(.8+.2*np.sin(2*np.pi*25*t)))
t=np.arange(int(RATE*.45))/RATE
save('screw',rng.normal(size=len(t))*.1*np.exp(-t*12)+sum(np.sin(2*np.pi*f*t)*np.exp(-t*d) for f,d in [(2100,30),(3300,40),(900,25)])*.2)
t=np.arange(int(RATE*.8))/RATE
save('dishes',sum(np.sin(2*np.pi*f*t)*np.exp(-t*d) for f,d in [(710,6),(1810,9),(2870,15),(4200,21)])*.2)
t=np.arange(int(RATE*1.2))/RATE
save('sweep',noise(len(t))*(np.sin(np.pi*t/1.2)**2)*(0.7+.3*np.sin(t*32)))
t=np.arange(RATE*6)/RATE
motor=np.sin(2*np.pi*(90*t+4*np.sin(2*np.pi*t/6)))+.35*np.sin(2*np.pi*(180*t+8*np.sin(2*np.pi*t/6)))
save('scooter_pass',(.16*motor+.12*noise(len(t)))*np.sin(np.pi*t/6)**3)
print('Wrote 5 original foley clips')
