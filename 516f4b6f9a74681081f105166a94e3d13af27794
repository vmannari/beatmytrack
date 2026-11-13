import json
import logging
import sys
from bmt_backend.observability import JsonFormatter, dependency_failure, failure_site


def own_failure():
    # Simulate an actual first-party stack without including any exception value.
    namespace = {'__name__': 'bmt_backend.site_fixture'}
    exec(compile('def fail():\n    raise ValueError("secret-token /private/owner?track=secret")\n', '/private/build/source.py', 'exec'), namespace)
    try:
        namespace['fail']()
    except ValueError as error:
        return error


def test_safe_deepest_site_and_request_correlation():
    error = own_failure()
    assert failure_site(error) == 'bmt_backend.site_fixture:fail:2'
    record = logging.LogRecord('bmt', logging.ERROR, __file__, 1, 'request_failed', (), (type(error), error, error.__traceback__))
    record.request_id = 'fixture-request'
    result = JsonFormatter().format(record)
    assert json.loads(result)['failure_site'] == failure_site(error)
    assert json.loads(result)['request_id'] == 'fixture-request'
    assert 'secret' not in result and '/private' not in result


def test_dependency_site_and_external_errors(caplog):
    dependency_failure(logging.getLogger('fixture'), own_failure(), 'request-2', 'database')
    result = json.loads(JsonFormatter().format(caplog.records[-1]))
    assert result['failure_site'] == 'bmt_backend.site_fixture:fail:2'
    assert result['exception_type'] == 'ValueError'
    assert failure_site(ValueError('secret')) == 'external'
    record = logging.LogRecord('bmt', logging.ERROR, __file__, 1, 'safe_event', (), None)
    record.failure_site = '/private/path?token=secret'
    assert 'secret' not in JsonFormatter().format(record)
