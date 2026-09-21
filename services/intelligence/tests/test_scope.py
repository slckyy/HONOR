from pathlib import Path
def test_c01_does_not_ship_intelligence_engine():
    p=Path(__file__).resolve().parents[1]/'honor_intelligence'; assert list(p.glob('*.py'))==[p/'__init__.py']
