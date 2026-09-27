// Offline audition renderer. TinySoundFont is downloaded by additive_bank.py.
#define TSF_IMPLEMENTATION
#include "tsf.h"
#include <algorithm>
#include <fstream>
#include <iostream>
#include <vector>
struct Event { int frame, key; float velocity; };
int main(int argc, char** argv) {
    if (argc != 6) return 2;
    tsf* font = tsf_load_filename(argv[1]);
    if (!font) return 3;
    const int preset = tsf_get_presetindex(font, std::stoi(argv[3]), std::stoi(argv[4]));
    if (preset < 0) { tsf_close(font); return 4; }
    constexpr int rate = 48000, length = 16 * rate;
    tsf_set_output(font, TSF_STEREO_INTERLEAVED, rate, -6);
    std::ifstream score(argv[2]);
    if (!score) return 5;
    std::vector<Event> events;
    double beat, duration; int key; float velocity;
    while (score >> beat >> duration >> key >> velocity) {
        for (int cycle = 0; cycle < 3; ++cycle) {
            events.push_back({cycle * length + int(beat * rate / 2 + .5), key, velocity});
            events.push_back({cycle * length + int((beat + duration) * rate / 2 + .5), key, 0});
        }
    }
    // Off before on when a pitch is retriggered at the same sample.
    std::sort(events.begin(), events.end(), [](const Event& a, const Event& b) {
        return a.frame == b.frame ? a.velocity < b.velocity : a.frame < b.frame;
    });
    std::vector<float> audio(3 * length * 2, 0);
    int cursor = 0;
    for (const auto& e : events) {
        if (e.frame >= 3 * length) break;
        if (e.frame > cursor) tsf_render_float(font, audio.data() + cursor * 2, e.frame - cursor, 0);
        cursor = e.frame;
        if (e.velocity) tsf_note_on(font, preset, e.key, e.velocity);
        else tsf_note_off(font, preset, e.key);
    }
    if (cursor < 3 * length) tsf_render_float(font, audio.data() + cursor * 2, 3 * length - cursor, 0);
    std::ofstream out(argv[5], std::ios::binary);
    // Third pass includes releases from the preceding phrase, including at loop-in.
    out.write(reinterpret_cast<char*>(audio.data() + length * 4), length * 2 * sizeof(float));
    tsf_close(font);
    return out ? 0 : 6;
}
