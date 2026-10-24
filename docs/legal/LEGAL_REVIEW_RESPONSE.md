# Beat my track terms review response

The revised [terms draft](TERMS_DRAFT.md) incorporates the supplied review and the publisher's subsequent decisions: **minimum age 13**, initial distribution in the **EU, US and Canada**, and operational/commercial wording for service discontinuation. It remains a draft. Publisher details, shutdown notice duration, product-specific withdrawal handling and regional implementation are still publication gates.

The supplied review describes itself as a specialist-style risk review, not a formal opinion from retained Finnish counsel. Its [exact text](../evidence/launch-compliance-2026-10-24/review-input.txt) and the [draft it reviewed](../evidence/launch-compliance-2026-10-24/terms-before-user-review.txt) are retained for comparison. The evidence report records their hashes. This response does not treat the review as legal sign-off.

## Changes and outstanding work

| Review point | Disposition in revision 2 | Remaining gate |
| --- | --- | --- |
| Publisher versus seller/provider | Section 1 separates the publisher's services from the transaction-specific seller/payment roles. | Real identities, geographical address and provider-country arrangements. |
| Minimum age and territories | Section 3 now states 13+ and EU/US/Canada, as the publisher instructed. | Age/country handling, relevant parental authorisation, truthful store audience and rating. |
| Minor purchases | Section 3 distinguishes access age, data choices and purchasing capacity, including repeated purchases. | Product/checkout controls and guardian handling appropriate to each market. |
| Publishing slots | Section 8 specifies single-use allocations, successful new-revision consumption, retry/failure treatment, no automatic return after hiding/removal, and no scheduled expiry of unused purchased allocations. | Confirm these current code semantics as the final commercial offer and validate actual billing/refund paths. |
| Alleged monthly free slot | Corrected: current code grants one initial allocation, not a recurring monthly allowance. No monthly promise added. | A monthly allowance would require a separate approved product and code change. |
| Ad-free scope | Section 8 explicitly suppresses automatic interruption ads and bypasses rewarded ads for the standard resumes, preserving banked/daily resources and the three-per-race cap. | Provider release/device acceptance; any other rewarded placement needs its own description. |
| Ad-free naming | Retains the current ad-free product names because the existing benefit already bypasses required rewarded resumes. | Reassess the name if the benefit is narrowed; listing and checkout must match. |
| Calendar-month edge cases | Section 8 defines UTC, later-of-current-expiry/grant start, last-day clamping and a January/February/March example. | Provider timestamps and displayed expiry must match the verified account ledger. |
| Guest/cross-device recovery | Section 5 requires a signed-in game account for real checkout and distinguishes server-held benefits from local files. Consumed packs restore remaining allocations, not a second grant. | Actual provider restore, wrong-account rejection and device acceptance. |
| Account deletion and purchases | Section 12 explains irreversible account closure, erasure of entitlements and new-account creation on later Google sign-in, while preserving legal/store claims. | A clear release confirmation and legal review of product-specific provider remedies. |
| Product-specific withdrawal | Section 9 retains a conspicuous completion gate rather than assigning an unverified legal classification to each SKU. | Classify each product, immediate supply/consent, durable confirmation, partial use, provider responsibility and applicable withdrawal function before sales. |
| Shutdown discretion | Section 14 now uses legitimate operational/technical/legal/commercial reasons and omits the personal-circumstances list, as the publisher confirmed. | Review fairness against permanent benefits and existing obligations. |
| Proposed 60-day notice | Not silently adopted. The draft contains an explicit notice-period/channel field. | Publisher must choose a commitment that can be honoured; 60 days was a proposal, not a statutory minimum. |
| Shutdown effects | Section 14 covers sales cutoff, paid benefits, outstanding orders, content retrieval, privacy and available offline functions. | Operational procedure, lawful remedies and applicable update duties. |
| Recording/streaming | Section 4 expressly permits ordinary screenshots, videos and streams, including monetised ones, for rights the publisher controls. | Audit third-party music/assets; the terms cannot license rights the publisher lacks. |
| Ownership of supplied assets | Section 7 separates publisher/licensor assets, protected original player contributions and limited operating permissions. | Final shipped asset/licence audit. |
| Private/social features | Section 7 covers submitted/shared challenges, authorised ghosts and podium/profile displays within disclosed audiences; it does not claim that private evidence becomes public. | Check actual access controls and privacy disclosures. |
| Promotion of player tracks | Section 7 does not add an unrestricted external-marketing licence. Separate permission or another applicable right is required. | Decide any future opt-in campaign permissions before using a player's work externally. |
| Bugs language | Section 15 removes the general as-is/as-available expression and states realistic limits plus agreed delivery/defect duties. | Specific material deviations still require appropriate disclosure/agreement. |
| Bans and redress | Proportionate temporary/permanent bans and discretionary-refund limits remain, with evidence, required reasons and legal/store redress. | Functioning staff access, procedures and paid-benefit review. |
| Sale and major redesign | Sections 13/19 preserve the requested rights, successor obligations, paid rights and personal-data safeguards. | Review an actual transaction or material change on its facts. |
| International language/support | Section 17 adds the regional language/contact gate and applicable Quebec French-contract process. | Qualified translations and market-specific legal/support arrangements. |
| Draft length/readability | Repeated qualifications have been shortened while preserving the 19-section structure and requested protections. | Check teen readability, translations and consistency with the final screens. |

## Product facts checked against source

These are descriptions of current source, not evidence that production purchases are enabled:

- [Entitlement model](../../backend/bmt_backend/commerce_models.py): one initial allocation, account-held remaining allocations and timed/permanent ad-free fields.
- [Commerce service](../../backend/bmt_backend/commerce.py): successful publication consumes an allocation per immutable version; retries of that version do not consume again. Grant/expiry logic has no monthly free-slot reset or scheduled paid-slot expiry. The January 2027 example follows the current UTC month-clamp function.
- [Publication acceptance](../../backend/bmt_backend/publications.py): publication and allocation consumption commit after acceptance, rather than charging a failed attempt.
- [Resume authority](../../backend/bmt_backend/resumes.py) and [client resume adapter](../../game/platform/resume_credits.gd): active ad-free benefits bypass the rewarded-ad path without spending banked/daily resumes; three resumes per race remain.
- [Privacy cleanup](../../backend/bmt_backend/privacy.py): deletion closes access, erases entitlements and prevents ordinary recovery of the deleted identity. [Appearance sync](../GARAGE_APPEARANCE_SYNC_2026_10_23.md) restores supported saved designs, not a full device backup.
- [Store](../../game/ui/store_page.gd) and [provider boundary](../../backend/bmt_backend/provider_proofs.py): live billing/fulfilment remain separate work. No purchase or provider restore was exercised for this revision.

## Regional work for the confirmed audience

**EU:** 13 is the game's access threshold. For consent-based processing within GDPR Article 8, national thresholds vary from 13 to 16. Identify the country/age rules, legal bases for essential processing and required parental processes; optional analytics/ads must not bypass them. Do not infer that a terms checkbox grants privacy consent. [European Commission guidance](https://commission.europa.eu/law/law-topic/data-protection/information-business-and-organisations/legal-grounds-processing-data/are-there-any-specific-safeguards-data-about-children_en).

**US:** assess the actual product/audience under COPPA and plan for actual knowledge of under-13 users. A 13+ clause alone does not establish that a product is not directed to younger children. Review the current rule and applicable state teen/privacy/advertising/consumer requirements, including each law's applicability thresholds, before claiming countrywide acceptance. This package does not automatically classify the game or require identity-document collection. [FTC guidance](https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions).

**Canada:** map federal and relevant provincial rules, meaningful youth consent and cross-border processing. Quebec's under-14 consent requirements need a specific route for 13-year-olds where applicable; do not assume an exception merely because the service is a game. Assess French-contract requirements and provide the required French version/process before a valid other-language choice. Canadian distribution is not implicitly limited to English-speaking provinces. [OPC provincial scope](https://www.priv.gc.ca/en/privacy-topics/privacy-laws-in-canada/the-personal-information-protection-and-electronic-documents-act-pipeda/r_o_p/prov-pipeda/), [Quebec consent guidance](https://www.cai.gouv.qc.ca/protection-renseignements-personnels/information-entreprises-privees/consentement-personnes-entreprises), [OQLF contract guidance](https://www.oqlf.gouv.qc.ca/francisation/entreprises/Contrats-adhesion.pdf).

**Purchases and notices:** map each SKU/provider to the relevant consumer regime and seller roles. Finnish guidance confirms both the special treatment of minors' repeated purchases and the need to distinguish digital content from services when handling withdrawal. The 2026 electronic withdrawal-function requirement remains a release check where applicable; neither a partly used item nor a simulator receipt settles it. [KKV minors](https://www.kkv.fi/en/consumer-affairs/children-as-consumers/childrens-mobile-game-purchases/), [KKV withdrawal](https://www.kkv.fi/en/consumer-affairs/online-stores/right-of-withdrawal-in-e-commerce/).

## Publication status

Keep sales and legal publication behind the actual release gates in the [checklist](LAUNCH_CHECKLIST.csv). This revision changes documents only. It does not implement age/parent controls, translations, real checkout, moderation access or withdrawal workflows. The supplied review, this response and document checks do not substitute for qualified final regional review or device/provider acceptance.
