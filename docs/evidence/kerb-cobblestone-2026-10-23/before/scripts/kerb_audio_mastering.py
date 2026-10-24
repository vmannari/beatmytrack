"""Dry tyre contacts and damped suspension chatter, authored offline."""
import numpy as np

REVISION = "tyre-body-6"
GENERATOR = "kerb-tyre-body-6"
SEED = 2026102261
PULSE_HZ = 6.0


def unit_rms(values):
    return values / max(float(np.sqrt(np.mean(values ** 2))), 1e-9)


def render(read, steady, filter_audio, write, rate):
    count = 8*rate
    rng = np.random.default_rng(SEED)
    # A restrained rubber bed connects the contacts without adding gravel hiss.
    rolling = unit_rms(filter_audio(rng.normal(size=count),low=85,high=700))*.028
    time = np.arange(round(.14*rate),dtype=np.float64)/rate
    attack = 1-np.exp(-time/.0009)
    for index in range(round(8*PULSE_HZ)):
        # Several short, fixed body modes replace the old falling sine note.
        # Broad rubber excitation carries most of the material character;
        # no long metallic resonance or audible pitched sweep is introduced.
        body = np.zeros_like(time)
        for hz, weight, decay in [(105,.45,.024),(185,.32,.019),(325,.24,.014),
                                  (570,.15,.009),(940,.08,.005)]:
            body += weight*np.sin(2*np.pi*hz*rng.uniform(.96,1.04)*time)*np.exp(-time/decay)
        rubber = unit_rms(filter_audio(rng.normal(size=len(time)),low=100,high=1700))
        contact = unit_rms(filter_audio(rng.normal(size=len(time)),low=380,high=3800))
        pulse = attack*(body*.85 + rubber*.42*np.exp(-time/.023)
                        + contact*.26*np.exp(-time/.006))
        # A small irregular secondary compression makes each strike less like
        # one identical drum hit, while retaining the established six-beat pace.
        delay = round(rng.uniform(.010,.017)*rate)
        echo = attack*rubber*np.exp(-time/.010)*.10
        pulse[delay:] += echo[:-delay]
        pulse[-round(.012*rate):] *= np.linspace(1,0,round(.012*rate))
        offset = round((index/PULSE_HZ+rng.uniform(-.0018,.0018))*rate)
        pressure = (.94+.09*np.sin(index*.47))*rng.uniform(.94,1.06)
        positions = (offset+np.arange(len(pulse)))%count
        rolling[positions] += pulse*pressure
    # Soft offline compression controls isolated noise spikes without the
    # texture levelling that would erase each contact's attack and decay.
    rolling = np.tanh(rolling*1.5)
    # Calibrated to the prior cue's -18.5 LUFS, rather than a louder audition.
    write("kerb_roll",filter_audio(rolling,low=65,high=3600),[],rms=.128)
