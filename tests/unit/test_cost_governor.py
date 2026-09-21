from decimal import Decimal
from honor_api.costs import state,GovernorState,admit,PaidClass,unfunded_reservation

def test_boundaries():
    cases={'42.99':'NORMAL','43.00':'OPTIONAL_PAUSED','43.01':'OPTIONAL_PAUSED','51.02':'OPTIONAL_PAUSED','51.03':'RESERVE','56.02':'RESERVE','56.03':'HARD_STOP'}
    for x,expected in cases.items():assert state(Decimal(x)).value==expected

def test_admission():
    assert admit(Decimal('42.99'),Decimal('0.005'),PaidClass.OPTIONAL)
    assert not admit(Decimal('43.00'),Decimal('0.001'),PaidClass.OPTIONAL)
    assert admit(Decimal('51.02'),Decimal('0.005'),PaidClass.CORE_REQUIRED)
    assert not admit(Decimal('51.02'),Decimal('0.020'),PaidClass.CORE_REQUIRED)
    assert admit(Decimal('56.02'),Decimal('0.005'),PaidClass.EMERGENCY_ALLOWED,'security')
    assert not admit(Decimal('56.03'),Decimal('0.001'),PaidClass.EMERGENCY_ALLOWED,'security')

def test_prepaid_not_double_counted():assert unfunded_reservation(Decimal('3.00'),Decimal('2.25'))==Decimal('0.750000')
