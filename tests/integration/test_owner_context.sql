-- Run after migrations and after inserting a matching auth.users/owner_profiles test UUID as admin.
BEGIN;
SELECT set_config('honor.owner_user_id','00000000-0000-0000-0000-000000000001',true);
SELECT current_setting('honor.owner_user_id',true);
COMMIT;
SELECT COALESCE(current_setting('honor.owner_user_id',true),'') = '' AS context_cleared;
