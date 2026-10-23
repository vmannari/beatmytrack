"""Build the original, shared vector medal atlas. No external assets or services.

The five rows of states per family use identical silhouettes/emblems. Both the
collection and the real garage wall sample this one atlas; no live badge renders.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def path(d: str, **attrs: str) -> str:
    return '<path d="' + d + '" ' + ' '.join(f'{k}="{v}"' for k, v in attrs.items()) + '/>'


def circle(x: float, y: float, r: float, **attrs: str) -> str:
    return f'<circle cx="{x}" cy="{y}" r="{r}" ' + ' '.join(f'{k}="{v}"' for k, v in attrs.items()) + '/>'


FLAG = 'M-16 19V-20M-15-18Q-6-24 2-18T19-18V3Q10 9 2 3T-15 3M-5-20V1M7-16V6M-14-9Q-5-15 3-9T18-9'
SHIELD = 'M0-23L20-16V0Q17 15 0 23Q-17 15-20 0V-16Z'
CUP = 'M-13-19H13V-8Q13 4 0 9Q-13 4-13-8ZM-13-14H-21V-6Q-21 2-11 2M13-14H21V-6Q21 2 11 2M0 9V20M-11 21H11'
CROWN = 'M-21-12L-13 15H13L21-12L8-3L0-22L-8-3ZM-13 21H13'
CAR = 'M-18 5V-4L-11-15H11L18-4V15H-18ZM-15-3H15M-18 7H18M-13 15V20M13 15V20M-13 3H-8M8 3H13'
TRACK = 'M-4-19H8Q23-19 23-5Q23 4 12 7L6 8Q1 9 1 17Q1 24-10 24Q-24 24-24 11V-6Q-24-19-4-19ZM-8-10H7Q14-10 14-4Q14 0 6 0Q-7 0-8 12Q-8 16-12 15Q-15 15-15 10V-6Q-15-10-8-10Z'
SNOW = 'M0-24V24M-21-12L21 12M-21 12L21-12M-7-18L0-11L7-18M-7 18L0 11L7 18M-19-3L-10-6L-12-16M19 3L10 6L12 16M-19 3L-10 6L-12 16M19-3L10-6L12-16'
TREE = 'M0-24L-15-5H-7L-21 12H-4V23H4V12H21L7-5H15Z'
DUNES = 'M-24 14Q-5-12 24 14M-24 22H24M-23 7Q-14-7 0-4M8-15A7 7 0 1 0 22-15A7 7 0 1 0 8-15'
STORM = 'M-21-2Q-27-14-13-16Q-6-29 7-18Q22-20 23-6Q27 1 17 4H8M2-10L-10 8H1L-4 24L14 1H4Z'
CITY = 'M-22 22V-1H-11V22M-11 22V-14H4V22M4 22V-5H21V22M-25 22H25M-5-8H-1M-5-1H-1M10 2H15M10 9H15M-18 6H-15M-18 13H-15M9-19A8 8 0 0 0 23-12A10 10 0 1 1 9-19'
COMPASS = 'M0-24V-18M0 18V24M-24 0H-18M18 0H24M8-9L-5-5L-9 9L5 5ZM-20 0A20 20 0 1 0 20 0A20 20 0 1 0-20 0'


def emblems() -> dict[str, str]:
    # Every family has an authored emblem, including distinct clean biome seals.
    icons = {
        'races': FLAG,
        'distance': 'M-18 23L-7-23H7L18 23M0-18V-9M0-3V7M0 14V21M-24 23H24',
        'clean': SHIELD + 'M-11-1L-3 8L13-9',
        'race_pb': 'M-22 20H22M-16 12V3H-6V12M-5 12V-8H5V12M6 12V-21H16V12M-18-10L-6-22M-14-22H-6V-14',
        'lap_pb': 'M-17-3A20 20 0 1 0 0-20M0-26V-16M-6-26H6M0 0L12-11M-27-12H-8M-30-4H-11M-26 4H-16',
        'precision': 'M-21 0A21 21 0 1 0 21 0A21 21 0 1 0-21 0M0-21V-15M21 0H15M0 21V15M-21 0H-15M0-11V0L9 6',
        'tracks': COMPASS,
        'fleet': 'M-22 4V-4L-17-13H-2L3-4V11H-22ZM-20-3H0M-17 11V16M-2 11V16M8-6L12-18H24L29-8V8H8M11-7H26M13 8V13M24 8V13',
        'biomes': 'M-22 1A22 22 0 1 0 22 1A22 22 0 1 0-22 1M-21 0H21M0-21Q-18 0 0 23Q18 0 0-21M-18-12H18M-18 13H18',
        'rivalry_wins': CUP,
        'rivalry_podiums': 'M-23 21V1H-8V21M-8 21V-13H8V21M8 21V8H23V21M-25 22H25M-2-23H2V-17',
        'rivalry_weeks': 'M-21-15H21V22H-21ZM-21-5H21M-12-22V-10M12-22V-10M-11 8L-3 16L12 0',
        'challenge_wins': 'M-20-21L20 19M-15-24L-24-15M13 14L22 5M17 22L24 15M20-21L-20 19M15-24L24-15M-13 14L-22 5M-17 22L-24 15',
        'friends': 'M-7-10A7 7 0 1 0-21-10A7 7 0 1 0-7-10M7-10A7 7 0 1 0 21-10A7 7 0 1 0 7-10M-25 13Q-25 0-14 0Q-4 0-4 13M25 13Q25 0 14 0Q4 0 4 13M-12 18L-4 24L11 10',
        'publications': 'M-21-20H11V-8M-21-20V23H18V3M-13-11H0M-13-3H-5M-9 14L-6 3L16-19L24-11L2 11ZM13-16L21-8',
        'creator_plays': TRACK + 'M-5-6L8 1L-5 8Z',
        'creator_reach': 'M-7-12A7 7 0 1 0 7-12A7 7 0 1 0-7-12M-13 18V11Q-13 0 0 0Q13 0 13 11V18M-16-6A5 5 0 1 0-26-6A5 5 0 1 0-16-6M16-6A5 5 0 1 0 26-6A5 5 0 1 0 16-6M-29 19V13Q-29 5-21 5M29 19V13Q29 5 21 5M-5 23H5',
        'washes': 'M0-24Q-17-5-17 6A17 17 0 0 0 17 6Q17-5 0-24ZM-8 7Q-8 14-1 15M22-23V-11M16-17H28',
        'customise': 'M-19 20L-11 0L11-22L22-11L0 11ZM-11 0L0 11M-17 14L-6 17M8-19L19-8M-21 24H21',
        'pb_streak': 'M-22 14L-9 1L0 10L17-17M5-17H17V-5M-22 23H22M-17-13L-10-20M-17-20L-10-13',
        'untouchable': SHIELD + 'M-8-11L8 11M8-11L-8 11M0-25V-30M24-13L28-16M-24-13L-28-16',
        'perfectionist': 'M0-24L23 0L0 24L-23 0ZM-23 0H23M0-24L-9 0L0 24L9 0ZM-7-5L-1 1L10-10',
        'king': CROWN,
        'odds': 'M-22 21L-8-2L2 12L16-13L24 21ZM-17-18L-9-26L-1-18M-9-26V-8',
        'seasons': 'M0-25V25M-25 0H25M-8-18L-18-8M8 18L18 8M-18 8L-8 18M8-18L18-8M-5-9L0-15L5-9M-15-1L-19 5L-11 5M9 0A6 6 0 1 0 21 0A6 6 0 1 0 9 0M-2 10V20M-6 12L2 18M2 12L-6 18',
        'comeback': CROWN + 'M-25 1Q-34-20-11-26M-20-28L-11-26L-16-18',
        'legend': TRACK + 'M0-11L3-3L12-3L5 2L8 11L0 6L-8 11L-5 2L-12-3L-3-3Z',
        'unbeaten': SHIELD + 'M-8-6A8 8 0 1 0 8-6A8 8 0 1 0-8-6M-5 4L-10 15L0 11L10 15L5 4',
        'full_grid': 'M-23-20H-5V-2H-23ZM5-20H23V-2H5ZM-23 7H-5V25H-23ZM5 7H23V25H5ZM-18-11H-10M10-11H18M-18 16H-10M10 16H18',
        'scholar': 'M0-13Q-12-23-25-16V17Q-12 10 0 21Q12 10 25 17V-16Q12-23 0-13ZM0-13V21M-18-9L-7-5M-18-1L-7 3M7-5L18-9M7 3L18-1',
    }
    for biome, d in [('pine', TREE), ('desert', DUNES), ('winter', SNOW), ('storm', STORM), ('night_city', CITY)]:
        icons['race_' + biome] = d
        # A smaller biome relief sits within the clean-driving shield.
        icons['clean_' + biome] = SHIELD
    return icons


PALETTES = [
    ('4a5d66', '263943', '1c2c34', '455b66', '516772'),
    ('efd1a1', 'bc8b5d', '64442c', '302923', 'f3d6aa'),
    ('f2f4ec', 'b1bec3', '5c707b', '25333d', 'ecf2f0'),
    ('fff0b5', 'd6b56a', '79612f', '343026', 'fff0b2'),
    ('f0fff7', 'bfdad8', '527d85', '243c45', 'e6fff8'),
]


def medal(index: int, tier: int, family: dict) -> str:
    prestige = family['prestige']
    metal_tier = 3 if prestige and tier else tier
    light, middle, dark, enamel, ink = PALETTES[metal_tier]
    x, y = (index % 10) * 128, (index // 10) * 640 + tier * 128
    items = [f'<g transform="translate({x} {y})">']
    # Twin woven ribbon tails, with a folded inset and V-cut ends.
    ribbon = '304652' if tier else '25363e'
    items += [path('M36 81L31 121L47 112L58 125L62 84ZM66 84L70 125L81 112L97 121L92 81Z', fill='#'+ribbon),
              path('M40 90L37 110M88 90L91 110', stroke='#64747a' if tier else '#2e424d', opacity='.5')]
    if prestige:
        points = []
        for i in range(24):
            angle = math.tau * i / 24 - math.pi / 2
            radius = 54 if i % 2 == 0 else 47
            points.append(f'{64 + math.cos(angle)*radius:.2f},{57 + math.sin(angle)*radius:.2f}')
        items.append('<polygon points="'+' '.join(points)+f'" fill="url(#rim{metal_tier})" stroke="#{dark}" stroke-width="1.5"/>')
    else:
        items += [circle(64, 59, 46, fill='#0a141c', opacity='.75'),
                  circle(64, 57, 46, fill=f'url(#rim{metal_tier})', stroke=f'#{dark}', **{'stroke-width': '1.2'})]
    items += [circle(64, 57, 41, fill='none', stroke=f'#{light}', **{'stroke-width': '.9', 'opacity': '.65'}),
              circle(64, 57, 38, fill=f'url(#face{metal_tier})', stroke=f'#{dark}', **{'stroke-width': '2'}),
              circle(64, 57, 34.5, fill='none', stroke=f'#{middle}', **{'stroke-width': '.6', 'opacity': '.5'})]
    for i in range(20):
        a = math.tau*i/20
        items.append(path(f'M{64+math.sin(a)*42:.2f} {57+math.cos(a)*42:.2f}L{64+math.sin(a)*44:.2f} {57+math.cos(a)*44:.2f}', stroke=f'#{dark}', **{'stroke-width': '.8'}))
    icon = emblems()[family['id']]
    motif = f'<g transform="translate(64 55) scale(.86)" fill="none" stroke="#{ink}" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round">{path(icon)}</g>'
    if family['id'].startswith('clean_'):
        biome_id = family['id'].replace('clean_', 'race_')
        motif = motif.replace('scale(.86)', 'scale(.94)')
        motif += f'<g transform="translate(64 53) scale(.46)" fill="none" stroke="#{ink}" stroke-width="3.7" stroke-linecap="round" stroke-linejoin="round">{path(emblems()[biome_id])}</g>'
    items.append(motif)
    # Laurel leaves frame prestigious emblems. No initials or repeating generic icon.
    if prestige:
        for side in [-1, 1]:
            items.append(path(f'M{64+side*12} 86Q{64+side*36} 80 {64+side*29} 39', fill='none', stroke=f'#{middle}', **{'stroke-width': '1.4'}))
            for j in range(5):
                px, py = 64+side*(24+4*math.sin(j*.7)), 77-j*7
                items.append(path(f'M{px:.2f} {py}q{side*11} -1 {side*6} -8q{-side*9} 1 {-side*6} 8', fill=f'#{middle}'))
    if tier:
        n = 1 if prestige else tier
        for i in range(n):
            px = 64+(i-(n-1)/2)*8
            items.append(path(f'M{px} 82l2.3 3l-2.3 3l-2.3-3Z', fill=f'#{light}'))
    else:
        items.append(path('M61 84V81A3 3 0 0 1 67 81V84M60 84H68V91H60Z', fill='none', stroke=f'#{ink}', **{'stroke-width': '1.3'}))
    items.append('</g>')
    return ''.join(items)


def build() -> None:
    catalog = json.loads((ROOT/'game/persistence/achievement_catalog.json').read_text(encoding='utf-8'))
    assert {f['id'] for f in catalog['families']} == set(emblems())
    defs = []
    for i, (light, middle, dark, enamel, _) in enumerate(PALETTES):
        defs.append(f'<linearGradient id="rim{i}" x1="0" y1="0" x2=".8" y2="1"><stop stop-color="#{light}"/><stop offset=".23" stop-color="#{middle}"/><stop offset=".49" stop-color="#{dark}"/><stop offset=".74" stop-color="#{middle}"/><stop offset="1" stop-color="#{light}"/></linearGradient>')
        defs.append(f'<radialGradient id="face{i}" cx=".35" cy=".25" r=".9"><stop stop-color="#{enamel}"/><stop offset="1" stop-color="#111d26"/></radialGradient>')
    svg = '<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="2560" viewBox="0 0 1280 2560"><defs>'+''.join(defs)+'</defs>'
    svg += ''.join(medal(i, tier, family) for i, family in enumerate(catalog['families']) for tier in range(5))+'</svg>\n'
    destination = ROOT/'game/assets/achievements/medals.svg'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(svg.encode('utf-8'))
    print(f'Built 40 unique emblems / 200 medal states: {destination.relative_to(ROOT)} ({len(svg)} bytes)')


if __name__ == '__main__':
    build()
