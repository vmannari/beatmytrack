"""Real cryptography/provider contracts tested offline, without purchases or ad grants."""
import base64
from datetime import datetime, timezone
from urllib.parse import quote, unquote_to_bytes

import pytest
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec

from bmt_backend.provider_proofs import InvalidProof, account_binding, validate_play, verify_admob


def purchase(**changes):
    return {"obfuscatedExternalAccountId": account_binding("player-a"),
        "productLineItem": [{"productId": "ad_free_month", "productOfferDetails": {
            "quantity": 1, "refundableQuantity": 1, "consumptionState": "CONSUMPTION_STATE_YET_TO_BE_CONSUMED"}}],
        "purchaseStateContext": {"purchaseState": "PURCHASED"},
        "purchaseCompletionTime": "2026-09-12T12:00:00Z", **changes}


def test_play_authority_is_provider_bound_to_account_exact_product_quantity_and_state():
    at = int(datetime(2026, 9, 12, 12, 0, tzinfo=timezone.utc).timestamp())
    assert validate_play(purchase(), 'ad_free_month', 'player-a', at=at)['completed_at'] == at
    with pytest.raises(InvalidProof, match='ACCOUNT'):
        validate_play(purchase(), 'ad_free_month', 'player-b', at=at)
    with pytest.raises(InvalidProof, match='PRODUCT'):
        validate_play(purchase(), 'creator_slot_1', 'player-a', at=at)
    with pytest.raises(InvalidProof, match='QUANTITY'):
        proof = purchase(); proof['productLineItem'][0]['productOfferDetails']['quantity'] = True
        validate_play(proof, 'ad_free_month', 'player-a', at=at)
    with pytest.raises(InvalidProof, match='STATE'):
        validate_play(purchase(purchaseStateContext={'purchaseState':'invented'}), 'ad_free_month', 'player-a', at=at)
    with pytest.raises(InvalidProof, match='TIME'):
        validate_play(purchase(purchaseCompletionTime='2030-01-01T00:00:00Z'), 'ad_free_month', 'player-a', at=at)
    pending = validate_play(purchase(purchaseStateContext={'purchaseState':'PENDING'}, purchaseCompletionTime=None), 'ad_free_month', 'player-a', at=at)
    assert pending['state'] == 'PENDING' and pending['completed_at'] is None
    assert validate_play(purchase(testPurchaseContext={'fopType':'TEST'}), 'ad_free_month', 'player-a', at=at)['test_purchase']


def test_ssv_verifies_exact_query_bytes_and_never_trusts_unsigned_decoded_params():
    private = ec.generate_private_key(ec.SECP256R1())

    class Keys:
        def key(self, identity):
            if identity != '1': raise InvalidProof('UNKNOWN_ADMOB_KEY')
            return private.public_key()

    raw = ('ad_network=5450213213286189855&ad_unit=123&custom_data='+quote('opaque/intent',safe='')+
        '&reward_amount=1&reward_item=resume&timestamp=1791737979545&transaction_id=abcdef').encode()

    def signed(value):
        signature = base64.urlsafe_b64encode(private.sign(unquote_to_bytes(value), ec.ECDSA(hashes.SHA256()))).rstrip(b'=')
        return value+b'&signature='+signature+b'&key_id=1'

    callback = signed(raw)
    assert verify_admob(callback, Keys())['custom_data'] == 'opaque/intent'
    # URI.getQuery() treats these equivalent wire representations identically.
    assert verify_admob(callback.replace(b'%2F',b'/'), Keys())['custom_data'] == 'opaque/intent'
    for altered in (callback.replace(b'ad_unit=123',b'ad_unit=456'), callback.replace(b'%2F',b'%252F'), callback+b'&reward_amount=1'):
        with pytest.raises(InvalidProof): verify_admob(altered, Keys())
    plus = signed(raw.replace(b'opaque%2Fintent', b'opaque+intent'))
    with pytest.raises(InvalidProof): verify_admob(plus.replace(b'+',b'%20',1), Keys())
    with pytest.raises(InvalidProof): verify_admob(signed(raw+b'&reward_amount=1'), Keys())
    with pytest.raises(InvalidProof): verify_admob(signed(raw.replace(b'reward_amount=1',b'reward_amount=100')), Keys())
    with pytest.raises(InvalidProof): verify_admob(b'x'*4097, Keys())
