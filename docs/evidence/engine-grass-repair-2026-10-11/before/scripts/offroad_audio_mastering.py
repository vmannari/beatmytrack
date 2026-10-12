"""Original uneven soil/grass rolling, rendered offline without field ambience."""
import numpy as np


def render(filter_audio, write, rate):
    def unit(values):
        return values/max(float(np.sqrt(np.mean(values**2))),1e-9)

    for name,rough,seed in [('grass',False,2026101154),('loose',True,2026101155)]:
        rng = np.random.default_rng(seed)
        count = 8*rate
        bed = unit(filter_audio(rng.normal(size=count),low=100,high=650,warmth=.45))
        # Smooth uneven pressure follows soil/turf contact, with no regular
        # kerb rhythm or repeated quiet-to-loud fade baked into the loop.
        times = [0.0]
        while times[-1]<8.0: times.append(times[-1]+rng.uniform(.18,.60))
        pressure = rng.uniform(.60,1.35,len(times))
        pressure[-1] = pressure[0]
        bed *= np.interp(np.arange(count)/rate,times,pressure)
        bumps = np.zeros(count)
        crunch = np.zeros(count)
        for target,density in [(bumps,5.0),(crunch,24.0 if rough else 15.0)]:
            cursor = 0.0
            while cursor<8.0:
                cursor += rng.uniform(.5,1.5)/density
                if cursor>=8.0: break
                duration = rng.uniform(.11,.19) if target is bumps else rng.uniform(.035,.09)
                time = np.arange(round(duration*rate))/rate
                if target is bumps:
                    # Low, overlapping rubber/body loading; not isolated hard
                    # suspension knocks and not the accepted repeating kerb cue.
                    phase = 2*np.pi*rng.uniform(105,155)*time
                    grain = np.sin(phase)*(1-np.exp(-time/.009))*np.exp(-time/.038)
                else:
                    grain = unit(filter_audio(rng.normal(size=len(time)),low=350,
                        high=2100 if rough else 1300))
                    grain *= (1-np.exp(-time/.006))*np.exp(-time/(duration*.28))
                grain[-round(.006*rate):] *= np.linspace(1,0,round(.006*rate))
                positions = (round(cursor*rate)+np.arange(len(grain)))%count
                target[positions] += grain*rng.uniform(.45,1.0)
        # Grass is soft tyre/soil rumble; gravel has more restrained crunch.
        values = bed*(.55 if rough else .72)+unit(bumps)*.20+unit(crunch)*(.25 if rough else .08)
        write(name,filter_audio(values,low=75,high=2300 if rough else 1500),[],rms=.14)
