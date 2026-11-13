"""Migration and query-plan rehearsal on synthetic data in an owned PostgreSQL schema."""
import hashlib
import json
import os
import uuid

from alembic import command
from sqlalchemy import create_engine, or_, select, text, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from bmt_backend.identity_models import Player
from bmt_backend.migrate import configuration, upgrade
from bmt_backend.receipt_references import FIELDS, reference
from bmt_backend.track_models import IdempotencyRecord

url = os.environ['BMT_TEST_DATABASE_URL']
schema = 'bmt_load_' + uuid.uuid4().hex
admin = create_engine(url)
with admin.begin() as connection:
    connection.execute(text('CREATE SCHEMA "' + schema + '"'))
engine = create_engine(url, connect_args={'options': '-c search_path=' + schema})
try:
    config = configuration(engine)
    command.upgrade(config, '0073_publication_publisher_check')
    with Session(engine) as db:
        owner = Player(display_name='Migration rehearsal')
        db.add(owner)
        db.flush()
        rows = [dict(player_id=owner.id, scope='fixture', key=str(i), request_hash='a'*64,
                     response={'unrelated': i}) for i in range(20000)]
        rows += [dict(player_id=owner.id, scope='fixture', key=field, request_hash='a'*64,
                      response={field: 'target'}) for field in FIELDS]
        rows += [dict(player_id=owner.id, scope='fixture', key='duplicate-run', request_hash='a'*64,
                      response={'run_id': 'target'})]
        db.execute(IdempotencyRecord.__table__.insert(), rows)
        db.commit()

    def digest():
        with Session(engine) as db:
            values = db.execute(select(IdempotencyRecord.key, IdempotencyRecord.response)
                                .order_by(IdempotencyRecord.key)).all()
            return hashlib.sha256(json.dumps([tuple(row) for row in values], sort_keys=True).encode()).hexdigest()

    before = digest()
    upgrade(engine)
    assert digest() == before
    command.downgrade(config, '0074_shader_profile_receipts')
    assert digest() == before
    # Model an interrupted concurrent build with a real invalid PostgreSQL index.
    with engine.connect().execution_options(isolation_level='AUTOCOMMIT') as connection:
        try:
            connection.exec_driver_sql("CREATE UNIQUE INDEX CONCURRENTLY ix_retry_run_id ON domain_idempotency "
                                       "((CAST(response ->> 'run_id' AS VARCHAR))) "
                                       "WHERE CAST(response ->> 'run_id' AS VARCHAR) IS NOT NULL")
        except IntegrityError:
            pass
        else:
            raise AssertionError('The duplicate synthetic reference must invalidate the unique build')
        assert connection.scalar(text("SELECT indisvalid FROM pg_index WHERE indexrelid=to_regclass('ix_retry_run_id')")) is False
    upgrade(engine)
    upgrade(engine)
    assert digest() == before
    predicate = or_(*(reference(IdempotencyRecord.response, field).in_(['target']) for field in FIELDS))
    query = update(IdempotencyRecord).where(predicate).values(response={'retired': True})
    compiled = query.compile(dialect=engine.dialect, compile_kwargs={'render_postcompile': True})
    parameters = {key: json.dumps(value) if isinstance(value, dict) else value for key, value in compiled.params.items()}
    with engine.begin() as connection:
        connection.exec_driver_sql('ANALYZE domain_idempotency')
        plan = connection.exec_driver_sql('EXPLAIN (ANALYZE, FORMAT JSON) ' + str(compiled), parameters).scalar()
        encoded = json.dumps(plan)
        assert all('ix_retry_' + field in encoded for field in FIELDS), encoded
        assert 'Seq Scan' not in encoded, encoded
        assert connection.scalar(text("SELECT count(*) FROM domain_idempotency WHERE response ->> 'retired' = 'true'")) == 5
        assert connection.scalar(text('SELECT version_num FROM alembic_version')) == '0075_receipt_reference_indexes'
    print('RELEASE_RESULT=' + json.dumps({'synthetic_only': True, 'rows': 20005,
          'migration_73_to_75': True, 'rollback_preserved_data': True, 'repeat_upgrade': True,
          'invalid_concurrent_index_recovered': True, 'all_four_indexes_used': True,
          'retired_rows': 5, 'schema': '0075_receipt_reference_indexes', 'plan': plan}), flush=True)
finally:
    engine.dispose()
    with admin.begin() as connection:
        connection.execute(text('DROP SCHEMA "' + schema + '" CASCADE'))
    admin.dispose()
