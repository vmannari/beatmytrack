import hashlib,json,shutil
from pathlib import Path
package=Path('/app/bmt_backend');game=Path('/opt/bmt/game')
assert package==Path('/app/bmt_backend') and game==Path('/opt/bmt/game')
shutil.rmtree(package);shutil.copytree('/tmp/release-backend',package)
shutil.rmtree(game);shutil.copytree('/tmp/release-canonical',game)
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade,SCHEMA_HEAD
assert SCHEMA_HEAD=='0070_reward_cache_revisions'
a=create_app(Settings(environment='test',database_url='sqlite://'))
upgrade(a.state.engine);a.state.engine.dispose();a.state.verifier.close()
proof={'schema':SCHEMA_HEAD,'source_hashes':{p.relative_to(package).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in package.rglob('*') if p.is_file() and '__pycache__' not in p.parts}}
Path('/app/full-release-proof.json').write_text(json.dumps(proof))
