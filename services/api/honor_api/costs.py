from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal
from enum import StrEnum
from typing import Any
from uuid import uuid4

D = lambda value: Decimal(str(value)).quantize(Decimal("0.000001"))
OPTIONAL = D("43.000000")
RESERVE = D("51.030000")
HARD = D("56.030000")


class GovernorState(StrEnum):
    NORMAL = "NORMAL"
    OPTIONAL_PAUSED = "OPTIONAL_PAUSED"
    RESERVE = "RESERVE"
    HARD_STOP = "HARD_STOP"


class PaidClass(StrEnum):
    OPTIONAL = "OPTIONAL"
    CORE_REQUIRED = "CORE_REQUIRED"
    EMERGENCY_ALLOWED = "EMERGENCY_ALLOWED"


@dataclass(frozen=True)
class Exposure:
    cash_spend_counted_usd: Decimal
    unpaid_committed_usd: Decimal
    admitted_queued_unfunded_usd: Decimal

    @property
    def total(self) -> Decimal:
        return D(
            self.cash_spend_counted_usd
            + self.unpaid_committed_usd
            + self.admitted_queued_unfunded_usd
        )


def state(exposure: Decimal) -> GovernorState:
    value = D(exposure)
    if value < OPTIONAL:
        return GovernorState.NORMAL
    if value < RESERVE:
        return GovernorState.OPTIONAL_PAUSED
    if value < HARD:
        return GovernorState.RESERVE
    return GovernorState.HARD_STOP


def admit(
    current: Decimal,
    reservation: Decimal,
    paid_class: PaidClass,
    purpose: str = "",
) -> bool:
    current = D(current)
    post = D(current + D(reservation))
    if D(reservation) <= 0:
        return True
    if current >= HARD or post >= HARD:
        return False
    if paid_class == PaidClass.OPTIONAL:
        return current < OPTIONAL and post < OPTIONAL
    if paid_class == PaidClass.CORE_REQUIRED:
        return current < RESERVE and post < RESERVE
    if paid_class == PaidClass.EMERGENCY_ALLOWED:
        return purpose in {"recovery", "security", "reconciliation"} and post < HARD
    return False


def unfunded_reservation(
    max_incremental: Decimal, remaining_prepaid_credit: Decimal
) -> Decimal:
    return D(max(Decimal("0"), D(max_incremental) - D(remaining_prepaid_credit)))


@dataclass(frozen=True)
class CostLedgerView:
    id: str
    provider: str
    service: str
    job_id: str | None
    polli_session_id: str | None
    estimated_cost_usd: Decimal
    actual_cost_usd: Decimal | None
    incurred_at: datetime
    idempotency_key: str
    status: str
    source_of_cost_data: str
    reconciliation_state: str
    reservation_kind: str


def classify_ledger_row(row: dict[str, Any]) -> CostLedgerView:
    service = str(row["service"])
    actual = row.get("actual_cost_usd")
    reconciled = row.get("reconciled_at")
    if service == "PREPAID_FUNDING":
        kind = "PREPAID_FUNDING"
    elif row.get("external_usage_id"):
        kind = "PROVIDER_USAGE"
    else:
        kind = "ADMITTED_OR_COMMITTED_RESERVATION"
    status = (
        "RECONCILED"
        if actual is not None and reconciled is not None
        else "RESERVED_OR_COMMITTED"
    )
    source = (
        "PROVIDER_RECONCILIATION"
        if row.get("external_usage_id")
        else "HONOR_PRE_DISPATCH_ESTIMATE"
    )
    return CostLedgerView(
        id=str(row["id"]),
        provider=str(row["provider"]),
        service=service,
        job_id=str(row["job_id"]) if row.get("job_id") else None,
        polli_session_id=(
            str(row["polli_session_id"]) if row.get("polli_session_id") else None
        ),
        estimated_cost_usd=D(row["estimated_cost_usd"]),
        actual_cost_usd=D(actual) if actual is not None else None,
        incurred_at=row["incurred_at"],
        idempotency_key=str(row["idempotency_key"]),
        status=status,
        source_of_cost_data=source,
        reconciliation_state="RECONCILED" if reconciled else "PENDING",
        reservation_kind=kind,
    )


class CostLedgerIdempotencyConflict(ValueError):
    pass


class CostLedgerRepository:
    """Persist C00 cost semantics without mutating immutable reservation fields."""

    def __init__(self, conn):
        self.conn = conn

    @staticmethod
    def _same_uuid(actual: Any, requested: str | None) -> bool:
        return (str(actual) if actual is not None else None) == requested

    @classmethod
    def _verify_replay(
        cls,
        row: Any,
        *,
        provider: str,
        service: str,
        cost_category: str,
        quantity: Decimal,
        unit: str,
        estimated_usd: Decimal,
        confidence: str,
        job_id: str | None,
        polli_session_id: str | None,
        actual_usd: Decimal | None,
        reconciled: bool | None,
    ) -> None:
        checks = {
            "provider": str(row["provider"]) == provider,
            "service": str(row["service"]) == service,
            "cost_category": str(row["cost_category"]) == cost_category,
            "quantity": D(row["quantity"]) == D(quantity),
            "unit": str(row["unit"]) == unit,
            "estimated_cost_usd": D(row["estimated_cost_usd"]) == D(estimated_usd),
            "cost_confidence": str(row["cost_confidence"]) == confidence,
            "job_id": cls._same_uuid(row["job_id"], job_id),
            "polli_session_id": cls._same_uuid(row["polli_session_id"], polli_session_id),
        }
        if actual_usd is not None:
            checks["actual_cost_usd"] = row["actual_cost_usd"] is not None and D(row["actual_cost_usd"]) == D(actual_usd)
        if reconciled is not None:
            checks["reconciled_at"] = (row["reconciled_at"] is not None) is reconciled
        mismatches = sorted(name for name, valid in checks.items() if not valid)
        if mismatches:
            raise CostLedgerIdempotencyConflict(
                "cost idempotency key reused with different immutable semantics: " + ",".join(mismatches)
            )

    async def _load_existing(self, idempotency_key: str):
        row = await self.conn.fetchrow(
            "SELECT * FROM cost_ledger WHERE idempotency_key=$1",
            idempotency_key,
        )
        if row is None:
            raise RuntimeError("cost idempotency conflict occurred but existing row was not visible")
        return row

    async def reserve(
        self,
        *,
        provider: str,
        service: str,
        cost_category: str,
        estimated_usd: Decimal,
        idempotency_key: str,
        job_id: str | None = None,
        polli_session_id: str | None = None,
        quantity: Decimal = Decimal("1"),
        unit: str = "OPERATION",
        confidence: str = "HIGH",
    ) -> CostLedgerView:
        quantity = D(quantity)
        estimate = D(estimated_usd)
        row = await self.conn.fetchrow(
            """
            INSERT INTO cost_ledger(
              id,provider,service,cost_category,job_id,polli_session_id,quantity,unit,
              estimated_cost_usd,cost_confidence,incurred_at,idempotency_key
            ) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,statement_timestamp(),$11)
            ON CONFLICT(idempotency_key) DO NOTHING
            RETURNING *
            """,
            uuid4(), provider, service, cost_category, job_id, polli_session_id,
            quantity, unit, estimate, confidence, idempotency_key,
        )
        if row is None:
            row = await self._load_existing(idempotency_key)
            self._verify_replay(
                row,
                provider=provider,
                service=service,
                cost_category=cost_category,
                quantity=quantity,
                unit=unit,
                estimated_usd=estimate,
                confidence=confidence,
                job_id=job_id,
                polli_session_id=polli_session_id,
                actual_usd=None,
                reconciled=None,
            )
        return classify_ledger_row(dict(row))

    async def record_prepaid_funding(
        self, *, provider: str, amount_usd: Decimal, idempotency_key: str
    ) -> CostLedgerView:
        amount = D(amount_usd)
        now = datetime.now(timezone.utc)
        row = await self.conn.fetchrow(
            """
            INSERT INTO cost_ledger(
              id,provider,service,cost_category,quantity,unit,estimated_cost_usd,
              actual_cost_usd,cost_confidence,incurred_at,reconciled_at,idempotency_key
            ) VALUES($1,$2,'PREPAID_FUNDING','AI_REASONING',$3,'USD_CASH_PURCHASE',
              $3,$3,'HIGH',$4,$4,$5)
            ON CONFLICT(idempotency_key) DO NOTHING
            RETURNING *
            """,
            uuid4(), provider, amount, now, idempotency_key,
        )
        if row is None:
            row = await self._load_existing(idempotency_key)
            self._verify_replay(
                row,
                provider=provider,
                service="PREPAID_FUNDING",
                cost_category="AI_REASONING",
                quantity=amount,
                unit="USD_CASH_PURCHASE",
                estimated_usd=amount,
                confidence="HIGH",
                job_id=None,
                polli_session_id=None,
                actual_usd=amount,
                reconciled=True,
            )
        return classify_ledger_row(dict(row))

    async def record_unpaid_commitment(
        self,
        *,
        provider: str,
        service: str,
        cost_category: str,
        committed_usd: Decimal,
        idempotency_key: str,
        job_id: str | None = None,
    ) -> CostLedgerView:
        return await self.reserve(
            provider=provider,
            service=service,
            cost_category=cost_category,
            estimated_usd=committed_usd,
            idempotency_key=idempotency_key,
            job_id=job_id,
            unit="COMMITTED_OPERATION",
            confidence="HIGH",
        )

    async def record_provider_usage(
        self,
        *,
        provider: str,
        service: str,
        captured_at: datetime,
        raw_usage: dict[str, Any],
        request_id: str | None = None,
        job_id: str | None = None,
        model_or_sku: str | None = None,
        input_units: int | None = None,
        output_units: int | None = None,
        audio_seconds: Decimal | None = None,
        duration_seconds: Decimal | None = None,
        storage_bytes: int | None = None,
        operation_count: int | None = None,
    ) -> str:
        usage_id = uuid4()
        inserted = await self.conn.fetchrow(
            """
            INSERT INTO provider_usage(
              id,provider,service,model_or_sku,request_id,job_id,input_units,output_units,
              audio_seconds,duration_seconds,storage_bytes,operation_count,raw_usage,captured_at
            ) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
            ON CONFLICT (provider,request_id) WHERE request_id IS NOT NULL DO NOTHING
            RETURNING id
            """,
            usage_id, provider, service, model_or_sku, request_id, job_id,
            input_units, output_units, audio_seconds, duration_seconds, storage_bytes,
            operation_count, raw_usage, captured_at,
        )
        if inserted is not None:
            return str(inserted["id"])
        if request_id is None:
            raise RuntimeError("provider usage insert unexpectedly returned no row")
        existing = await self.conn.fetchrow(
            "SELECT id,service,job_id FROM provider_usage WHERE provider=$1 AND request_id=$2",
            provider,
            request_id,
        )
        if existing is None or str(existing["service"]) != service or not self._same_uuid(existing["job_id"], job_id):
            raise CostLedgerIdempotencyConflict("provider request id reused with conflicting semantics")
        return str(existing["id"])

    async def reconcile(self, ledger_id: str, actual_usd: Decimal) -> CostLedgerView:
        row = await self.conn.fetchrow(
            """
            UPDATE cost_ledger
               SET actual_cost_usd=$2,
                   reconciled_at=statement_timestamp()
             WHERE id=$1
               AND actual_cost_usd IS NULL
               AND reconciled_at IS NULL
            RETURNING *
            """,
            ledger_id,
            D(actual_usd),
        )
        if row is None:
            raise ValueError("cost ledger row is absent or already reconciled")
        return classify_ledger_row(dict(row))
