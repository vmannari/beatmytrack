# Original vector emblems. Strong silhouettes and deliberate negative space remain
# readable both on the car and in the small menu cards; no fonts or outside art.
N,C,A,W = '#172c3b','#eeddbb','#d1a25b','#f6f1e6'
TEAL,RED = '#5b9290','#bb6250'

def outlined(d, fill, edge=N, width=3):
    return f'<path d="{d}" fill="{fill}" stroke="{edge}" stroke-width="{width}" stroke-linejoin="round"/>'

def star(x,y,r,colour=A):
    return path('M'+'L'.join(f'{x+(r if i%2==0 else r*.44)*math.sin(i*math.pi/5):.2f} {y-(r if i%2==0 else r*.44)*math.cos(i*math.pi/5):.2f}' for i in range(10))+'Z',colour)

def disc():
    return circle(128,128,111,N)+circle(128,128,107,W)+circle(128,128,99,N)+circle(128,128,91,A,2)

shield = outlined('M128 17L218 49V119C218 169 180 213 128 239C76 213 38 169 38 119V49Z',W)
shield += path('M128 29L207 57V119C207 163 174 202 128 226C82 202 49 163 49 119V57Z',N)
shield += path('M128 40L196 64V119C196 155 169 189 128 213C87 189 60 155 60 119V64Z',A,2)
# Three complete custom letterforms, including the previously missing T.
crest = shield+path('M72 82H91C107 82 109 102 98 109C112 116 107 137 91 137H72Z',W)
crest += path('M82 92H90Q98 92 98 99Q98 105 90 105H82Z M82 115H91Q100 115 100 121Q100 127 91 127H82Z',N)
crest += path('M115 137V82H126L137 104L148 82H159V137H148V103L137 124L126 103V137Z M166 82H200V93H188V137H177V93H166Z',W)
crest += path('M80 155H176L168 169H88Z',A)+star(128,191,12)
# An actual open counter in the zero, balanced numeral widths and side accents.
roundel = disc()+circle(128,128,82,C)
roundel += f'<path d="M68 82H104Q115 82 115 94V161Q115 173 104 173H68Q57 173 57 161V94Q57 82 68 82ZM77 98V157H95V98Z" fill="{N}" fill-rule="evenodd"/>'
roundel += path('M128 82H199V99L163 173H140L175 102H128Z',N)+path('M87 192H169',A,5)
compass = disc()+circle(128,128,79,TEAL,3)
for i in range(4):
    compass += f'<g transform="rotate({45+i*90} 128 128)">{path("M128 61L138 118L128 133L118 118Z",C)}</g>'
for i in range(4):
    compass += f'<g transform="rotate({i*90} 128 128)">{outlined("M128 35L148 108L128 128L108 108Z",W)}{path("M128 35V128L148 108Z",A)}</g>'
compass += circle(128,128,13,N)+circle(128,128,6,W)
summit = outlined('M128 18L242 224H14Z',W)+path('M128 38L225 214H31Z',N)
summit += path('M47 197L106 82L134 132L161 94L211 197Z',TEAL)
summit += path('M106 82L85 123L105 116L119 126L127 120Z M161 94L141 124L160 120L175 130Z',W)
summit += path('M47 197L106 147L135 171L161 142L211 197Z',C)+path('M64 204H192',A,4)
bolt = shield+outlined('M143 50L77 137H121L107 204L181 112H137Z',A,W,3)
bolt += path('M143 50L94 128H129',W,3)
# Swept wings with clean separated feathers rather than a nested chevron.
phoenix = outlined('M128 232C91 209 58 174 39 130L18 49L84 88L74 30L118 75L128 59L138 75L182 30L172 88L238 49L217 130C198 174 165 209 128 232Z',W)
phoenix += path('M128 214C92 191 67 158 51 119L36 76L100 116L91 61L121 97L128 83L135 97L165 61L156 116L220 76L205 119C189 158 164 191 128 214Z',N)
phoenix += path('M128 196L69 115L111 139L108 105L128 127L148 105L145 139L187 115Z',RED)
phoenix += path('M128 171L103 133L128 147L153 133Z',A)+path('M118 88H138L128 108Z',C)
# Bone silhouettes stay behind the skull. Rounded cranial dome, cheekbones, jaw.
skull = path('M54 211L204 57M52 57L204 211',N,23)+path('M54 211L204 57M52 57L204 211',C,14)
for x,y in [(48,51),(59,62),(198,51),(209,62),(48,217),(59,206),(198,217),(209,206)]:
    skull += circle(x,y,8,C)
skull += outlined('M128 31C82 31 56 60 56 105C56 130 65 145 82 154L91 169V202Q91 214 103 214H153Q165 214 165 202V169L174 154C191 145 200 130 200 105C200 60 174 31 128 31Z',W)
skull += path('M72 104Q94 90 114 111L108 140L88 143L74 128Z M184 104Q162 90 142 111L148 140L168 143L182 128Z',N)
skull += path('M128 135L116 160H140Z',N)+path('M103 182V205M119 182V207M137 182V207M153 182V205',N,5)
skull += path('M96 172Q128 181 160 172',A,3)
orbital = disc()
# Far half of the orbital ring is occluded by the planet; near half crosses it.
orbital += '<ellipse cx="128" cy="128" rx="115" ry="35" transform="rotate(-28 128 128)" fill="none" stroke="'+W+'" stroke-width="9"/>'
orbital += outlined('M189 128A61 61 0 1 1 67 128A61 61 0 1 1 189 128Z',A)
orbital += path('M109 78C86 92 77 117 84 141',C,6)+circle(105,105,8,C)
orbital += '<path d="M13 128A115 35 0 0 0 243 128" transform="rotate(-28 128 128)" fill="none" stroke="'+W+'" stroke-width="9"/>'
orbital += star(191,55,13,W)
laurel = disc()+circle(128,128,72,N)+star(128,115,37,W)+path('M103 163H153',A,5)
# Paired lanceolate leaves follow a curved branch, with visible negative spaces.
branch = path('M116 216C67 195 49 134 76 57',A,4)
for x,y,angle in [(77,72,-22),(65,99,-10),(62,128,5),(69,156,21),(84,183,36)]:
    branch += f'<g transform="translate({x} {y}) rotate({angle})">'+outlined('M0 12C-23 5-28-12-20-22C-7-20 1-7 0 12Z',C,N,2)+outlined('M1 12C20 0 24-13 17-23C5-17-1-3 1 12Z',TEAL,N,2)+'</g>'
laurel += branch+f'<g transform="translate(256 0) scale(-1 1)">{branch}</g>'
piston = disc()+outlined('M85 52Q128 43 171 52V119Q128 129 85 119Z',C)
piston += path('M86 68Q128 75 170 68M86 86Q128 93 170 86M86 104Q128 111 170 104',N,6)
piston += outlined('M116 126H140L145 169H111Z',A)+circle(128,186,31,W)+circle(128,186,17,N)+circle(128,186,9,TEAL)
piston += path('M96 56Q128 51 160 56',W,4)
# Each check follows the cloth's top and bottom curves; none escape the silhouette.
def flag_point(u,v):
    top=49-13*math.sin(u*math.pi*2)
    bottom=153-13*math.sin(u*math.pi*2)
    return 76+u*150-v*15,top+(bottom-top)*v

def flag_band(u0,u1,v0,v1):
    points=[flag_point(u,v0) for u in [u0+(u1-u0)*i/8 for i in range(9)]]
    points += [flag_point(u,v1) for u in [u1-(u1-u0)*i/8 for i in range(9)]]
    return 'M'+'L'.join(f'{x:.3f} {y:.3f}' for x,y in points)+'Z'
flag_shape=flag_band(0,1,0,1)
checker=path('M43 222L76 34',N,18)+path('M43 222L76 34',W,12)+circle(76,33,7,A)
checker += outlined(flag_shape,W,N,4)
checker += ''.join(path(flag_band(i/5,(i+1)/5,j/4,(j+1)/4),N) for i in range(5) for j in range(4) if (i+j)%2==0)
checker += path(flag_shape,A,3)
sun = disc()
for i in range(12):
    angle=i*math.pi/6
    sun += path(f'M{128+72*math.sin(angle):.2f} {128-72*math.cos(angle):.2f}L{128+82*math.sin(angle):.2f} {128-82*math.cos(angle):.2f}',C,5)
sun += circle(128,128,58,A)
sun += path('M72 139Q128 105 184 139L180 150Q128 118 76 150Z',N)
sun += path('M84 165Q128 142 172 165L163 176Q128 160 93 176Z',N)+path('M106 187H150',W,4)
stickers = [
    ('crest','BMT Crest',crest),('roundel','Race 07',roundel),
    ('compass','Compass',compass),('summit','Summit',summit),
    ('bolt','High Voltage',bolt),('phoenix','Phoenix',phoenix),
    ('skull','Ghost Rider',skull),('orbital','Orbital',orbital),
    ('laurel','Laurel',laurel),('piston','Piston Club',piston),
    ('checker','Checkered Flag',checker),('sun','Desert Sun',sun),
]
atlas = ''
for i,(key,title,art) in enumerate(stickers):
    # Keep the existing 256px cells / 16px gutters and shared mipmapped shader.
    atlas += f'<g transform="translate({i%4*256+16} {i//4*256+16}) scale(.875)">{art}</g>'
    (ROOT/(key+'_sticker.svg')).write_text(svg(art,256,256,'0 0 256 256'),encoding='utf-8')
height = math.ceil(len(stickers)/4)*256
(ROOT/'stickers.svg').write_text(svg(atlas,1024,height,f'0 0 1024 {height}'),encoding='utf-8')
(ROOT/'stickers.json').write_text(json.dumps([{'id':k,'title':t} for k,t,_ in stickers],indent=2)+'\n',encoding='utf-8')
print(f'Authored {len(patterns)} livery masks/previews and {len(stickers)} original stickers.')
