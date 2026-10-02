-- 002_default_scripts.sql — the two products the panel exposes.
-- Both start OFFLINE: nothing is served until an admin runs /scriptonline.
-- Replace `source` with your real Lua via `npm run seed:script`.

INSERT INTO scripts (slug, name, version, status, public_script, private_script, source)
VALUES
  ('public', 'Public Script', '1.0.0', 'offline', TRUE,  FALSE,
   '-- Public script placeholder. Upload the real source with: npm run seed:script\nprint("orbit: public script placeholder")\n'),
  ('private', 'Private Hub', '1.0.0', 'offline', FALSE, TRUE,
   '-- Private hub placeholder. Upload the real source with: npm run seed:script\nprint("orbit: private hub placeholder")\n')
ON CONFLICT (slug) DO NOTHING;
