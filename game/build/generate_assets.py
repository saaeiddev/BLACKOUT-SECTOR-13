from PIL import Image, ImageDraw
import numpy as np, pathlib, wave
root=pathlib.Path(__file__).resolve().parents[1]/'assets';rng=np.random.default_rng(1306);n=512
for folder in ['textures','audio','ui']:(root/folder).mkdir(parents=True,exist_ok=True)
for name,base in [('concrete',(83,94,98)),('metal',(54,64,70)),('floor',(43,50,56)),('flesh',(94,76,70)),('glove',(39,44,41))]:
 a=np.clip(np.array(base).reshape(1,1,3)+rng.normal(0,6,(n,n,1)),0,255).astype('uint8');im=Image.fromarray(a);d=ImageDraw.Draw(im)
 if name=='concrete':
  for y in [0,256,511]:d.line((0,y,511,y),fill=(36,42,46),width=3)
  for x in [0,511]:d.line((x,0,x,511),fill=(40,48,50),width=2)
  for x in [25,487]:
   for y in [28,230,282,486]:d.ellipse((x-5,y-5,x+5,y+5),fill=(45,50,52))
 elif name=='floor':
  for x in range(-512,1024,22):
   for y in range(0,512,32):d.line((x+(y%64)//2,y,x+8+(y%64)//2,y+7),fill=(87,98,101),width=3)
  d.rectangle((0,0,511,511),outline=(23,29,32),width=5)
 elif name=='metal':
  for _ in range(120):
   x,y=rng.integers(0,512,2);d.line((int(x),int(y),int(min(511,x+rng.integers(3,100))),int(y)),fill=(95,95,86),width=1)
  d.rectangle((0,0,511,511),outline=(25,31,34),width=5)
 elif name=='flesh':
  for _ in range(42):
   x,y=rng.integers(0,512,2);pts=[(int(x),int(y))]
   for i in range(6):pts.append((pts[-1][0]+int(rng.integers(-14,15)),pts[-1][1]+int(rng.integers(9,30))))
   d.line(pts,fill=(50,51,44),width=2)
 else:
  for y in range(0,512,5):d.line((0,y,511,y),fill=(46,50,46))
 im.save(root/'textures'/f'{name}.png')
sr=22050
for name,dur in {'pistol':.42,'shotgun':.8,'step':.25,'reload':1.45,'pickup':.4,'hit':.28,'door':1.8,'growl':1.8,'attack':.9,'alarm':2,'hum':8,'music':16,'death':2,'terminal':1,'empty':.12}.items():
 t=np.arange(int(sr*dur))/sr;noise=rng.normal(0,1,len(t))
 if name in ['pistol','shotgun']:
  freq=75 if name=='shotgun' else 135;a=.46*noise*np.exp(-t*(12 if name=='shotgun' else 23))+.42*np.sin(2*np.pi*freq*t*np.exp(-t*3))*np.exp(-t*9)+.18*noise*np.exp(-((t-.045)/.01)**2)
 elif name=='step':a=.20*noise*np.exp(-t*25)+.3*np.sin(2*np.pi*90*t)*np.exp(-t*30)
 elif name=='reload':a=sum(.18*noise*np.exp(-((t-c)/.02)**2)+.12*np.sin(2*np.pi*(450+c*90)*t)*np.exp(-((t-c)/.035)**2) for c in [.05,.48,.82,1.2])
 elif name=='pickup':a=.16*(np.sin(2*np.pi*660*t)+np.sin(2*np.pi*990*t))*np.exp(-t*8)
 elif name=='hit':a=.3*noise*np.exp(-t*20)+.2*np.sin(2*np.pi*120*t)*np.exp(-t*12)
 elif name=='door':a=.08*noise*np.sin(np.pi*t/dur)+.13*np.sin(2*np.pi*(80+20*t)*t)*np.sin(np.pi*t/dur)+.25*noise*np.exp(-((t-1.65)/.07)**2)
 elif name=='growl':a=(.12*np.sin(2*np.pi*(55*t+7*np.sin(t*4)))+.10*np.sin(2*np.pi*88*t)*np.sin(t*12)+.02*noise)*np.sin(np.pi*t/dur)
 elif name=='attack':a=(.22*noise+.16*np.sin(2*np.pi*65*t))*np.sin(np.pi*t/dur)**2
 elif name=='alarm':a=.11*np.sin(2*np.pi*(550*t+80*np.sin(t*2.5)))*np.sin(np.pi*t/dur)**2
 elif name=='hum':a=.07*np.sin(2*np.pi*50*t)+.035*np.sin(2*np.pi*101*t)+.012*noise
 elif name=='music':a=(.065*np.sin(2*np.pi*41.25*t)+.026*np.sin(2*np.pi*61.875*t)*(1+.45*np.sin(2*np.pi*t/8))+.01*noise)*np.minimum(1,t)*np.minimum(1,dur-t)
 elif name=='death':a=.2*np.sin(2*np.pi*(90*t-15*t*t))*np.exp(-t*2)+.04*noise*np.exp(-t*2)
 elif name=='terminal':a=.1*np.sin(2*np.pi*880*t)*((t%0.3)<0.12)*np.exp(-t*1.5)
 else:a=.2*noise*np.exp(-t*80)
 with wave.open(str(root/'audio'/f'{name}.wav'),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(sr);f.writeframes((np.clip(a,-.97,.97)*32767).astype('<i2').tobytes())
im=Image.new('RGBA',(256,256),(13,20,24,255));d=ImageDraw.Draw(im);d.polygon([(55,12),(201,12),(244,55),(244,201),(201,244),(55,244),(12,201),(12,55)],fill=(235,134,52));d.polygon([(73,34),(182,34),(221,73),(221,182),(182,221),(73,221),(34,182),(34,73)],fill=(20,30,35));d.polygon([(144,42),(82,141),(126,141),(110,213),(184,112),(141,112)],fill=(242,149,59));im.save(root/'ui/icon.png');im.save(root/'ui/icon.ico',sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])
print('Original assets generated')
