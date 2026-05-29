// rishot — pure Qt-key -> Hyprland/xkb keyname mapping for the hotkey recorder. No Qt imports
// at module scope (Qt.Key_* values are passed in by the caller). Produces the bind string used
// in rishot.lua, e.g. {key:Qt.Key_P, modifiers:CTRL|SHIFT, text:"p"} -> "CTRL + SHIFT + P".

// Qt::Key enum values we name explicitly (numeric to stay Qt-import-free + node-testable).
var NAMED_KEYS = {
    0x01000009: "Print",        // Qt.Key_Print  (SysReq/Print)
    0x01001007: "Print",        // Qt.Key_SysReq -> treat as Print
    0x01000000: "Escape",
    0x01000001: "Tab",
    0x01000004: "Return",       // Qt.Key_Return
    0x01000005: "Return",       // Qt.Key_Enter (keypad) -> Return
    0x20:       "Space",
    0x01000006: "Insert",
    0x01000007: "Delete",
    0x01000010: "Home",
    0x01000011: "End",
    0x01000016: "PageUp",       // Qt.Key_PageUp
    0x01000017: "PageDown",     // Qt.Key_PageDown
    0x01000012: "Left",
    0x01000013: "Up",
    0x01000014: "Right",
    0x01000015: "Down"
};

// Modifier bit names, low->high so the order is stable: SUPER CTRL ALT SHIFT.
var MOD_BITS = [
    { mask: 0x10000000, name: "SUPER" },   // Qt.MetaModifier
    { mask: 0x04000000, name: "CTRL" },    // Qt.ControlModifier
    { mask: 0x08000000, name: "ALT" },     // Qt.AltModifier
    { mask: 0x02000000, name: "SHIFT" }    // Qt.ShiftModifier
];

// Bare modifier keys: pressing only a modifier should NOT capture (keep listening).
var MODIFIER_KEYS = {
    0x01000020: true, 0x01000021: true,    // Shift L/R (Qt.Key_Shift)
    0x01000022: true, 0x01000023: true,    // Control (Qt.Key_Control)
    0x01000024: true,                      // CapsLock
    0x01000025: true,                      // Meta (Super) Qt.Key_Meta
    0x01000026: true,                      // Alt   Qt.Key_Alt
    0x01001103: true                       // AltGr Qt.Key_AltGr
};

// F1..F35 occupy a contiguous Qt range starting at Qt.Key_F1 (0x01000030).
var F1 = 0x01000030, F35 = 0x01000052;

// Resolve a Qt key event to a bare Hyprland key name, or null if it should be ignored.
// `key` = event.key (int), `text` = event.text (string).
function keyName(key, text) {
    if (MODIFIER_KEYS[key]) return null;                 // bare modifier -> ignore
    if (NAMED_KEYS[key]) return NAMED_KEYS[key];
    if (key >= F1 && key <= F35) return "F" + (key - F1 + 1);
    if (key >= 0x41 && key <= 0x5a) return String.fromCharCode(key + 32); // A-Z -> a-z
    if (key >= 0x30 && key <= 0x39) return String.fromCharCode(key);      // 0-9
    // fallback: a single printable char from event.text
    if (text && text.length === 1 && text.charCodeAt(0) >= 0x20) return text;
    return null;
}

// List active modifier names in canonical order. `modifiers` = event.modifiers bitmask.
function modNames(modifiers) {
    var out = [];
    for (var i = 0; i < MOD_BITS.length; i++)
        if (modifiers & MOD_BITS[i].mask) out.push(MOD_BITS[i].name);
    return out;
}

// Full Hyprland bind string for a Qt key event, or null if not yet a complete chord.
// e.g. "CTRL + SHIFT + P", "SUPER + S", "Print", "F5", "a".
function bindString(key, modifiers, text) {
    var k = keyName(key, text);
    if (k === null) return null;
    var parts = modNames(modifiers);
    parts.push(k);
    return parts.join(" + ");
}

// The full lua line for rishot.lua given a bind string.
function luaLine(bind) {
    return 'hl.bind("' + bind + '", hl.dsp.exec_cmd("qs -c rishot"))';
}

// Whole-file contents for rishot.lua with `bind` as the hotkey.
function luaFile(bind) {
    return "-- rishot screenshot keybind. Single source of truth for the hotkey\n"
        + "-- (Phase 2b's settings UI rewrites this file).\n"
        + luaLine(bind) + "\n";
}

// Parse the current bind string out of a rishot.lua file's text. Returns the bind or null.
function parseBind(luaText) {
    var m = /hl\.bind\(\s*"([^"]*)"/.exec(luaText);
    return m ? m[1] : null;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { keyName: keyName, modNames: modNames, bindString: bindString,
        luaLine: luaLine, luaFile: luaFile, parseBind: parseBind };
}
