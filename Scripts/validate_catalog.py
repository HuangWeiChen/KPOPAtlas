"""Validate catalog references and coverage without network access."""
import json
from pathlib import Path
from urllib.parse import urlparse

root = Path(__file__).resolve().parents[1]
catalog = json.loads((root / 'KPOPAtlas/Resources/catalog.json').read_text())
companies, groups = catalog['companies'], catalog['groups']
company_ids = {c['id'] for c in companies}
assert len(company_ids) == len(companies), 'Duplicate company IDs'
assert len({g['id'] for g in groups}) == len(groups), 'Duplicate group IDs'
assert len({g['name'] for g in groups}) == len(groups), 'Duplicate group names'
member_ids = []
for company in companies:
    assert urlparse(company['website']).scheme == 'https', company['name']
    assert any(g['companyID'] == company['id'] for g in groups), f'Empty company: {company["name"]}'
for group in groups:
    assert group['companyID'] in company_ids, group['name']
    assert 1990 <= group['debutYear'] <= 2026, group['name']
    assert group['kind'] in ['女團', '男團', '樂團', '混聲團'], group['name']
    assert group['wikipediaTitle'].strip(), group['name']
    assert group['memberNames'] and all(m.strip() == m and m for m in group['memberNames']), group['name']
    assert len(set(group['memberNames'])) == len(group['memberNames']), group['name']
    member_ids.extend(group['id'] + ':' + name for name in group['memberNames'])
assert len(set(member_ids)) == len(member_ids), 'Duplicate member identities'
by_name = {g['name']: g for g in groups}
assert len(by_name['BTS']['memberNames']) == 7
assert len(by_name['TWICE']['memberNames']) == 9
assert len(by_name['SEVENTEEN']['memberNames']) == 13
assert len(by_name['tripleS']['memberNames']) == 24
assert {'Jisoo', 'Jennie', 'Rosé', 'Lisa'} == set(by_name['BLACKPINK']['memberNames'])
print(f'PASS: {len(companies)} companies, {len(groups)} groups, {len(member_ids)} historical member entries')
print('PASS: unique IDs, company references, required fields, URLs, roster sanity checks')

# Enrichment must point at stable IDs, and every curated photo must carry credit.
from datetime import date
enrichment = json.loads((root / 'KPOPAtlas/Resources/enrichment.json').read_text())
valid_groups = {g['id'] for g in groups}
valid_members = set(member_ids)
assert len({p['memberID'] for p in enrichment['profiles']}) == len(enrichment['profiles'])
assert len({p['id'] for p in enrichment['photos']}) == len(enrichment['photos'])
for story in enrichment['stories']:
    assert story['groupID'] in valid_groups
    date.fromisoformat(story['debutDate'])
    assert story['sources'] and all(urlparse(s['url']).scheme == 'https' for s in story['sources'])
for profile in enrichment['profiles']:
    assert profile['memberID'] in valid_members, profile['memberID']
    assert profile['wikipediaTitle'] and urlparse(profile['sourceURL']).scheme == 'https'
    if profile['birthday']: date.fromisoformat(profile['birthday'])
for photo in enrichment['photos']:
    assert photo['groupID'] in valid_groups
    assert all(photo[field] for field in ['author', 'license', 'caption'])
    assert all(urlparse(photo[field]).scheme == 'https' for field in ['sourceURL', 'imageURL', 'licenseURL'])
    assert photo['width'] > 0 and photo['height'] > 0
print(f"PASS: {len(enrichment['photos'])} credited photos, {len(enrichment['stories'])} stories, {len(enrichment['profiles'])} profiles; references and dates valid")

manifest = json.loads((root / 'KPOPAtlas/Resources/media-manifest.json').read_text())
for category, valid in [('groups', valid_groups), ('members', valid_members), ('companies', {c['id'] for c in companies})]:
    for key, photo in manifest[category].items():
        assert key in valid, key
        assert all(photo[field] for field in ['author', 'license', 'caption'])
        assert all(urlparse(photo[field]).scheme == 'https' for field in ['sourceURL', 'imageURL', 'licenseURL'])
        assert photo['width'] > 0 and photo['height'] > 0
print('PASS: bundled media manifest', {key: len(value) for key, value in manifest.items()})
