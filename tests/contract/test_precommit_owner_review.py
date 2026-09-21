from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]
def test_round12_precommit_contract_preserved():
    sql=(ROOT/'infrastructure/migrations/0001_c00_database_contract.sql').read_text()
    assert "review_phase'<>'PRECOMMIT'" in sql
    sm=json.loads((ROOT/'docs/architecture/c00-approved/HONOR_STATE_MACHINES.json').read_text())
    rule=sm['owner_action']['restriction_resolution']
    assert 'PRECOMMIT' in rule and 'target_version' in rule and 'subject_sha256' in rule
    assert 'owner_review_resolution_id' in sql and 'subject_sha256' in sql and 'target_version' in sql
