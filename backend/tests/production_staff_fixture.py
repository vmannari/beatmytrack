"""Named MFA staff for tests of production-only support behavior."""

import json
from dataclasses import replace


def install(app):
    subjects = {
        "fixture-owner": {"name": "Owner", "role": "owner"},
        "fixture-analyst": {"name": "Analyst", "role": "analyst"},
    }
    app.state.settings = replace(
        app.state.settings,
        studio_legacy_keys_enabled=False,
        admin_owner_key="",
        admin_analyst_key="",
        temporary_ad_resumes_enabled=False,
        workload_role="admin",
        studio_staff_audiences=("staff",),
        studio_staff_subjects=json.dumps(subjects),
    )

    class Verifier:
        def verify(self, token):
            from fastapi import HTTPException

            subject = {"o" * 40: "fixture-owner", "a" * 40: "fixture-analyst"}.get(token)
            if subject is None:
                raise HTTPException(401, "INVALID_STAFF_TOKEN")
            return {"sub": subject, "amr": ["mfa"]}

    app.state.staff_identity_verifier = Verifier()
