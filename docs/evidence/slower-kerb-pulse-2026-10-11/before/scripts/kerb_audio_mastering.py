"""Original clean tyre vibration, generated offline without a field recording."""
import numpy as np


def render(read, steady, filter_audio, write, rate):
    count = 8*rate
    rng = np.random.default_rng(2026101151)
    hz = np.fft.rfftfreq(count,1/rate)
    # Broad damped rubber/body resonances, excited by original noise. Wide
    # bands avoid a pitched engine hum; the upper rolling band adds concrete
    # texture without the hiss, traffic or engine of the rejected recording.
    body_shape = (np.exp(-.5*((hz-135)/48)**2)
                  +.70*np.exp(-.5*((hz-265)/85)**2)
                  +.25*np.exp(-.5*((hz-490)/135)**2))
    body = np.fft.irfft(np.fft.rfft(rng.normal(size=count))*body_shape,n=count)
    rubber = filter_audio(rng.normal(size=count),low=300,high=1150)
    body /= max(float(np.sqrt(np.mean(body**2))),1e-9)
    rubber /= max(float(np.sqrt(np.mean(rubber**2))),1e-9)
    time = np.arange(count,dtype=np.float64)/rate
    # A shallow continuous flutter suggests tread loading over kerb ridges.
    # It never closes into a gap or triggers a train of individual impacts.
    # Slow phase/pressure variation keeps a short perfectly regular beat out.
    phase = 24*time+.11*np.sin(2*np.pi*.625*time)+.07*np.sin(2*np.pi*1.375*time)
    flutter = .82+.18*np.cos(2*np.pi*phase)
    pressure = 1+.07*np.sin(2*np.pi*.375*time)+.04*np.sin(2*np.pi*.875*time)
    rolling = (body*.86+rubber*.14)*flutter*pressure
    write("kerb_roll",filter_audio(rolling,low=70,high=1400),[],rms=.15)
