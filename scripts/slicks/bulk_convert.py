"""Offline corpus conversion. Prefer v2 names; preserve original seven fixtures.

Legacy gameplay normalization is verified against overlapping v2 files by tests.
No source file, palette or SS decoder is required by the game.
"""
import argparse
import concurrent.futures
import copy
import hashlib
import json
import tempfile
import zipfile
from pathlib import Path

from convert import convert
from slicks_ss_parser import parse_ss, parse_checkpoint, coord3, be16
from slicks_track_renderer_corrected import parse_dat

ROOT = Path(__file__).resolve().parents[2]
ORIGINAL = ['FREEWAY', '1WAY', '66', 'OFFROAD', 'ARTO4', 'HIEKKA', 'OVAALI3']
FICTIONAL = ['Mira Driftwood', 'Theo Gravel', 'Nora Apex', 'Elias Brook', 'Lina Cedar', 'Owen Vale', 'Ada Coast', 'Finn Meadows']


def normalize(path):
    data = parse_ss(path)
    if data['format_version'] == 2:
        return data
    raw = bytes.fromhex(data['legacy_tail_hex'])
    count, off = raw[0], 1
    data['checkpoints'] = [parse_checkpoint(raw[off+i*6:off+(i+1)*6]) for i in range(count)]
    off += count*6
    count = be16(raw[off:off+2]); off += 2
    data['computer_points'] = []
    for _ in range(count):
        data['computer_points'].append({'effect_a':coord3(raw[off:off+3]), 'effect_b':coord3(raw[off+3:off+6]), 'target':coord3(raw[off+6:off+9]), 'extra':0})
        off += 9
    count = be16(raw[off:off+2]); off += 2
    data['panic_points'] = [{'position':coord3(raw[off+i*3:off+(i+1)*3]), 'extra':0} for i in range(count)]
    off += count*3
    if len(raw)-off != 4:
        raise ValueError('Unrecognized legacy gameplay tail')
    data['start'] = {'x':be16(raw[off:off+2]), 'y':raw[off+2], 'direction':raw[off+3], 'reserved':'0000'}
    return data


def author_metadata(source, name):
    author = ' '.join(source['author'].split())
    if author:
        return {'creator':author, 'creator_kind':'source', 'source_author':source['author']}
    index = int(hashlib.sha256(name.upper().encode()).hexdigest()[:8], 16) % len(FICTIONAL)
    return {'creator':FICTIONAL[index], 'creator_kind':'fictional', 'source_author':source['author']}


def sources(archives, handoff):
    result = {}
    for archive_path in archives:
        with zipfile.ZipFile(archive_path) as archive:
            for member in sorted(archive.namelist()):
                if not member.lower().endswith('.ss'): continue
                blob = archive.read(member)
                name = Path(member).stem.upper()
                if name not in result or blob[5] > result[name][0][5]:
                    result[name] = (blob, str(archive_path.name), member)
    for path in sorted((handoff/'original_tracks').glob('*.SS')):
        result[path.stem.upper()] = (path.read_bytes(), 'slicks_codex_handoff.zip', path.name)
    return result


def worker(job):
    name, blob, archive, member, dat, config, output = job
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory)/(name+'.SS'); path.write_bytes(blob)
        source = normalize(path)
        resources, _ = parse_dat(Path(dat))
        target = Path(output)/('slicks_'+name.lower()+'_test.json')
        notes = []
        if name in config.get('scale_overrides', {}):
            notes.append('Uniform vehicle-clearance scale multiplier: '+str(config['scale_overrides'][name]))
        if name in ORIGINAL and target.exists():
            # Keep reviewed geometry, IDs, hashes/PBs and golden tests stable.
            native = json.loads(target.read_text(encoding='utf8'))
        else:
            try:
                native = convert(path, resources, config, source)
            except ValueError as error:
                if 'No car-clear route' not in str(error): raise
                fallback = copy.deepcopy(config); fallback['route_mode'] = 'source_hints'
                native = convert(path, resources, fallback, source)
                notes.append('Source-order route hints retained: '+str(error))
            native.update(author_metadata(source,name))
            native.setdefault('title', name.replace('_',' ').title())
            native.setdefault('theme', ['pine','coast','desert'][int(hashlib.sha256(name.encode()).hexdigest()[:8],16)%3])
            native['provenance']['format_version'] = source['format_version']
            native['provenance']['archive'] = archive
            native['provenance']['conversion_notes'] = notes
            target.write_bytes((json.dumps(native,separators=(',',':'))+'\n').encode('utf8'))
        return {'id':native['identity'], 'name':native.get('title',name), **author_metadata(source,name), 'theme':native.get('theme','pine'), 'path':'res://resources/tracks/'+target.name,
                'source_file':member,'archive':archive,'source_version':source['format_version'], 'source_sha256':hashlib.sha256(blob).hexdigest(), 'native_sha256':hashlib.sha256(target.read_bytes()).hexdigest(), 'notes':notes}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', action='append', type=Path, required=True)
    parser.add_argument('--handoff',type=Path,required=True)
    parser.add_argument('--output',type=Path,default=ROOT/'game/resources/tracks')
    parser.add_argument('--workers',type=int,default=4)
    args = parser.parse_args()
    config = json.loads(Path(__file__).with_name('config.json').read_text())
    extra = json.loads(Path(__file__).with_name('corpus_config.json').read_text())
    for role, ids in extra.pop('semantic_blocks').items(): config['semantic_blocks'][role].extend(ids)
    config.update(extra)
    inventory = sources(args.archive,args.handoff)
    args.output.mkdir(parents=True,exist_ok=True)
    jobs = [(name,*value,str(args.handoff/'SLICKS.DAT'),config,str(args.output)) for name,value in sorted(inventory.items())]
    entries, errors = [], []
    with concurrent.futures.ProcessPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(worker,job):job[0] for job in jobs}
        for future in concurrent.futures.as_completed(futures):
            name = futures[future]
            try:
                entry = future.result(); entries.append(entry)
                print('CONVERTED',name,entry['creator'], '; '.join(entry['notes']),flush=True)
            except Exception as error:
                errors.append({'name':name,'error':str(error)})
                print('FAILED',name,str(error),flush=True)
    entries.sort(key=lambda entry:(ORIGINAL.index(entry['source_file'].removesuffix('.SS')) if entry['source_file'].removesuffix('.SS') in ORIGINAL else len(ORIGINAL),entry['id']))
    manifest = {'schema':'builtin-track-catalog-v1','entries':entries,'failures':errors,
                'archives':[{ 'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in args.archive]}
    (args.output.parent/'builtin_tracks.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n',encoding='utf8')
    print('TOTAL',len(entries),'converted;',len(errors),'failed',flush=True)
    return bool(errors)


if __name__ == '__main__': raise SystemExit(main())
