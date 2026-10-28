# Beat my track second terms review response

Historical review response prepared 25 October 2026 for revisions 3–4, incorporating the [second supplied review](../evidence/launch-compliance-2026-10-24/second-review-input.txt), accompanying discussions and regional-withdrawal instruction. The [revision-2 baseline](../evidence/launch-compliance-2026-10-24/terms-before-second-review.txt) is preserved.

**Subsequent publisher decisions supersede the proposals below:** [the current decision record](PUBLISHER_DECISIONS_2026_10_25.md) selects one initial free slot, creator-immutable/no-hide publications, 60 days' in-game notice and no purchase transfer after deliberate whole-account deletion. The current [terms draft](TERMS_DRAFT.md) is revision 6 and replaces permanent ad-free with twelve months paid once without automatic renewal. Unexpired access survives reinstall on the same existing account. The permanent-product and automatic-restoration designs below are retained as history, not the selected implementation. Annual billing/expiry, ordinary recovery, deletion warnings and mandatory remedies need implementation/review. Neither the discussions nor this response establish legal enforceability or release acceptance.

## Decisions reflected in revision 3

| Topic | Revised position | Work still required |
| --- | --- | --- |
| Account deletion | Permanent account closure; erased progress/history and spent slots are not recreated. Local files are not remotely deleted. | App/web confirmation must accurately explain affected data and benefits. |
| Permanent ad-free | Valid non-consumable ownership survives voluntary game-account deletion; verified restoration to an eligible new account costs no second purchase price. | Implement store proof, one active game-account grant, account-switch/retry safeguards and support resolution before selling it. |
| Other paid benefits | Spent slots are not replenished; unused allocations/monthly time do not automatically carry to a new account after voluntary deletion. Mandatory remedies remain. | Review this product-specific treatment, disclose it prominently and avoid accidental deletion before warning. |
| Published tracks | Continuing, normally non-withdrawable community content; broad non-exclusive commercial, promotion, adaptation and successor licence for the applicable rights' duration. Original protected contributions remain the player's. | Fresh valid permissions, clear publication confirmation, regional/minor contracting review and legacy-content mapping. |
| Private content and identity | Private drafts/evidence do not become promotional material merely through submission; track permissions are not consent to advertise a player's identity. | Preserve audience/privacy controls and lawful identifying-data handling. |
| Publisher removals | Reasonable moderation, privacy, legal, security, compatibility and operational removal remains possible; hosting is not promised forever. | Required reasons/review and statutory removal/retrieval process. |
| Automated moderation | Describes local word/pattern rejection of names and human review; no claim of automatic account bans or perfect detection. | Deploy the matching policy/version and provide working review contacts and restriction explanations. |
| Ad-free scope | Current interstitials suppressed, standard rewarded resumes bypassed; no current banner placement. Existing benefits cannot be undermined by new compulsory ads. | Verify actual release SDK formats, listing and checkout. |
| Competition | Authorised resumes do not alone disqualify official records or Weekly Rivalry; verification and mode limits apply equally. Circuit races give all entrants up to three free resumes. Publication qualification requires a run without resumes. | Confirm actual candidate behaviour and explain these rules in player-facing competition information. |

The previously requested operational/commercial shutdown, major gameplay changes, IP sale/successor operation, proportionate bans, monetised gameplay recordings and realistic service limits remain. The draft does not add blanket refund/complaint exclusions, an inactivity-deletion power or compulsory arbitration merely because another publisher uses them.

## Resolve permanent purchases before sales

Fingersoft's official support confirms irreversible game-account deletion. That is evidence of its published practice, not proof that every forfeiture or liability clause is enforceable for this product. [HCR2 account deletion](https://fingersoft.helpshift.com/hc/en/3-hcr2/faq/75-i-deleted-my-account-can-i-get-it-back/?p=ios/), [Fingersoft EULA](https://fingersoft.com/eula-web/).

Google documents that an already-owned purchase can block another purchase and recommends querying existing purchases. Its security guidance requires backend verification and account/abuse checks. An order number or Google game sign-in alone is not sufficient proof of ownership. These support the restoration design; they do not themselves decide every consumer-law remedy. [Already-owned purchases](https://developer.android.com/google/play/billing/errors), [purchase verification](https://developer.android.com/google/play/billing/security).

Implement the following through the existing commerce/provider boundary, without restoring an erased identity:

1. Query the original purchasing store on an explicit restore action and verify the package, permanent SKU, purchase state, original transaction/token and current refund/revocation state on the server. A screenshot or unverified client callback grants nothing.
2. Authenticate the target game account and prove the requester controls the relevant store purchase. Resolve the old account binding through a reviewed deletion-specific flow; do not simply bypass an obfuscated-account mismatch or accept arbitrary cross-account transfers.
3. Atomically bind one active entitlement to the eligible target account. Deduplicate retries and concurrent claims across devices/accounts. A purchase still active on another account needs recovery/support resolution, not a second simultaneous grant. Deletion followed by restoration must not issue extra slots or recreate erased progress, identity links or revoked consents.
4. Keep refund/revocation reconciliation effective after rebinding. A lawful ban requires individual review under section 11 and applicable remedies; the restore route must neither enable ban evasion nor automatically confiscate unrelated legitimate purchases.
5. Minimise retained evidence and set lawful purposes, access controls and retention periods. Current cleanup erases account entitlements; retaining an opaque historical player is not proof of anonymous data. Review both cleanup and reconciliation before promising this flow publicly.

Test with provider sandbox ownership, voluntary deletion/new account, wrong store account, existing active binding, two simultaneous restore claims, lost response/retry, refund before and after restoration, and deletion/backup recovery. If verification cannot resolve ownership, provide a human support route. An unresolved already-owned purchase must not be met with an instruction to buy it again. Checklist LCP-39 is a release gate; this task has implemented none of this runtime behaviour.

## Continuing track rights without changing ownership

Section 7 now expressly permits commercial use and promotion of **published tracks** in Beat my track, future versions/platforms and related game services. It also permits derivatives and compatibility/gameplay changes without a fresh permission for every adaptation within that agreed scope. This revises the earlier separate-promotion-permission position for newly licensed public tracks. Private submissions retain the narrower feature licence. Unrelated standalone sales, unrelated advertising and AI training are not authorised.

Finnish copyright law distinguishes adaptation/transfer permissions from protected moral rights. Explicitly agreeing to modifications and sublicensing is preferable to claiming ownership of every layout, but a blanket moral-rights waiver is unsuitable. Regional review must also cover contracting capacity for the confirmed 13+ audience. [Copyright Act, sections 3, 28 and 29](https://finlex.fi/fi/lainsaadanto/1961/404).

“Normally non-withdrawable” is a default publication rule, not an absolute override of law. GDPR concerns identifying information even when a game object remains. Under digital-content termination rules, continued use of non-personal user-created content and retrieval can also be restricted, with defined exceptions. A game-specific layout may fit an exception; that is an assessment, not an automatic exemption for every track, embedded name or promotional export. Comply with required cessation/removal/retrieval. [Directive 2019/770, Article 16(2)–(4)](https://eur-lex.europa.eu/eli/dir/2019/770/oj/eng/pdf).

Before rollout:

- Record which licence/version each existing track was actually published under. The current [community terms](../../backend/bmt_backend/community.py) are `bmt-community-2026-10-16` and provide narrower operating permissions. Do not infer the new promotion/derivative licence from old acceptance, inactivity or mere continued use. Obtain valid fresh agreement covering identified prior tracks where needed, or keep their uses within existing permissions.
- Present the new licence and normal non-withdrawal rule before a slot is spent, with an explicit account-bound publication action and saved version/hash/time. Show the audience and exact slot cost, including revisions if the current policy is retained. Preserve retry/idempotency and account fences.
- Make compatibility adaptations as properly versioned content under the established immutable hashes/race contracts. Permission to modify a work does not authorise silently rewriting pinned race evidence or attributing new times to an old layout. Decide separate records/migration before a gameplay change.
- Keep removal/erasure, required export and identifying-data redaction operational. Removing a creator display name alone does not prove anonymity; downloaded copies and backups need the applicable handling too.

Proposed confirmation copy, subject to the publishing-policy decision:

> **Publish this track version?**
>
> Publishing uses one slot. This track normally becomes continuing community content and cannot be withdrawn just because you change your mind or delete your account. Other players may continue racing it. Under section 7 of the terms, we may adapt it for future game versions and use it to operate, develop and promote Beat my track and related game services. Mandatory removal, privacy and other legal rights remain.
>
> Read and save the terms before confirming. **Publish & use 1 slot** / **Cancel**.

This is proposed copy, not a shipped screen. It must appear before commitment and link to the readable full licence; it does not replace valid agreement or a legally required parental process.

## Publishing economy remains a decision

The review describes an earlier monthly free slot and free revisions. Current [commerce](../../backend/bmt_backend/commerce.py) and [entitlement model](../../backend/bmt_backend/commerce_models.py) instead implement **one initial free allocation** and **one allocation per successfully published immutable version**, including revisions. Failed/unverified attempts and exact same-version retries do not spend another allocation.

Two choices have been put to the publisher: initial versus monthly free allowance, and paid versus free published revisions. Revision 3 provisionally retains source behaviour. It does not confirm that the review's proposed economy is implemented or approve either new economic policy by silence. Resolve these before final copy/checkout; if monthly slots or free revisions are chosen, implement and verify them first. A free-revision design still needs a rule distinguishing a revision from a new logical track. Immutability and paid-slot accounting need not have the same granularity.

## Teenagers, languages and moderation

The review's Canadian date is verified: the OPC launched its Children's Privacy Code on **20 October 2026**. It interprets PIPEDA for children and teens and states expectations including meaningful consent, protective defaults, minimisation, age-appropriate transparency, practical correction/deletion and avoiding marketing profiling. Comments remain open until 20 January 2027; it is regulatory guidance, not a newly enacted standalone statute. Add it to the regional assessment alongside applicable provincial law, Quebec's under-14 consent rules and French contract delivery. [OPC announcement](https://www.priv.gc.ca/en/opc-news/news-and-announcements/2026/nr-c_261020/), [Children's Privacy Code](https://www.priv.gc.ca/en/privacy-topics/privacy-for-businesses/protection-of-children-for-businesses/childrens-privacy-code/children-code-final-report-2026/).

The earlier [regional work](LEGAL_REVIEW_RESPONSE.md) remains open: separate access age from privacy consent, purchase/contract capacity and permitted advertising; handle actual knowledge of under-13 users where required. Review public profile/default sharing and publication for teenagers rather than assuming 13+ removes youth protections. The English draft is not the applicable Quebec French-first contract process.

The [local name filter](../LOCAL_NAME_FILTER_2026_10_24.md) checks new naming writes and names underlying new challenges/rematches. It is not a general automated analysis of every track shape or an automatic ban system. Provide a human route for suspected false positives and explain automation in restriction notices when required. Ensure reports, decisions and reviews actually have operator coverage. Applicable DSA terms/reason-giving duties require accurate descriptions, including automated involvement; small-enterprise exemptions must be assessed individually. [Traficom hosting guidance](https://www.traficom.fi/en/data-economy-and-data-intermediation/hosting-services).

## Publication gates

The publisher subsequently instructed that discontinuation may be geographical where regulations become too challenging. Revision 4 adds express lawful, proportionate regional suspension/restriction/withdrawal of game distribution and/or services, including where compliance costs or complexity become unsustainable, while operation can continue elsewhere. This is broader than a prohibition-only trigger. Section 14 retains notice, affected-scope disclosure, sales cutoff, paid-benefit remedies and required data/content handling. LCP-31 and the [launch plan](LAUNCH_COMPLIANCE_PLAN.md) record implementation and regional legal review; no actual territory withdrawal or runtime block is implemented.

The [checklist](LAUNCH_CHECKLIST.csv) now expressly includes permanent-purchase restoration, published-track permission/confirmation/legacy handling, and automated-filter transparency/review. Existing gates still cover publisher identity and contacts, shutdown notice duration/channels, product classification/withdrawal, real billing/refunds, youth safeguards, languages, moderation and one accepted release candidate.

Only draft documents and their evidence change here. No effective community terms, acceptances, game economy, deletion logic, entitlements, UI, provider configuration or live service are changed. The documents remain **unpublished and not effective**. Mechanical document checks are not runtime verification, legal sign-off or proof that the proposed restore flow exists.
