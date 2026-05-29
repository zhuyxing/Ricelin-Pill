-- rishot screenshot keybind. Single source of truth for the hotkey
-- (Phase 2b's settings UI rewrites this file).
hl.bind("Print", hl.dsp.exec_cmd("flock -n /tmp/rishot.lock qs -c rishot"))
