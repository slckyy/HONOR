# Database migrations

Order: `0000_extensions_and_role.sql`, then the byte-for-byte C00 DDL in `0001_c00_database_contract.sql`, then `0002_runtime_security.sql`.

The approved C00 SQL has one PL/pgSQL body whose unparenthesized `CASE` is rejected by PostgreSQL function-body validation. `scripts/migrate.py` disables body validation only for the exact approved C00 SHA-256 while executing that file byte-for-byte. `0002_runtime_security.sql` immediately replaces that guard with the syntax-equivalent parenthesized definition, with normal validation restored, before application activation. This is a parser-compatibility repair only; the frozen C00 file and behavior remain unchanged.

Production uses `DATABASE_ADMIN_URL`. `honor_app` is deliberately created without a committed password. `infrastructure/deployment/scripts/provision-runtime-role.sh` binds a password supplied only via a protected deployment secret and then constructs `DATABASE_APP_URL` outside source control.

For disposable non-Supabase PostgreSQL integration tests, `tests/integration/bootstrap_auth_stub.sql` creates only the minimal `auth.users(id uuid)` table needed by C00 foreign keys. It is **test-only** and is never part of production migration order.
