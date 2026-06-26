#!/usr/bin/env python3
"""
Tier-3 fallback handlers for the Ricelin installer. These cover the packages
that have no native package on a given distro family, so the installer has to
fetch them another way: build from source, pull a prebuilt release, run a
crate install, or hand off to Flathub or a project's own installer.

Each handler returns an ordered list of steps and nothing runs here. A step is
either {"desc": ..., "run": [argv...]} for a plain command, or
{"desc": ..., "shell": "..."} when it needs a pipe or a redirect. The installer
decides when and how to execute them; this module only describes the work.
"""
import os
import shlex

from distro import PM, load_manifest

# Where user-level assets land. Fonts, cursors and source-built binaries go under
# the home directory so no root is needed for those, only for the udev and
# package-manager steps.
FONT_DIR = os.path.expanduser("~/.local/share/fonts")
ICON_DIR = os.path.expanduser("~/.local/share/icons")
BIN_DIR = os.path.expanduser("~/.local/bin")

# One shell prelude that guarantees cargo is on PATH: bootstrap rustup when cargo
# is missing, then source ~/.cargo/env so the freshly installed cargo is reachable
# in this very shell. The trailing source uses ';' (not '&&') on purpose, so a box
# that already has cargo from its distro, with no ~/.cargo/env to source, still
# falls through to the build instead of aborting on the missing file.
_CARGO_PREP = (
    "command -v cargo >/dev/null 2>&1 || "
    "(curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y); "
    '. "$HOME/.cargo/env"'
)


def _pm_install(family, pkg):
    """The native install argv for one package on this family, sudo included."""
    pm = PM.get(family, "")
    if pm == "pacman":
        return ["sudo", "pacman", "-S", "--needed", "--noconfirm", pkg]
    if pm == "apt-get":
        return ["sudo", "apt-get", "install", "-y", pkg]
    if pm == "dnf":
        return ["sudo", "dnf", "install", "-y", pkg]
    if pm == "zypper":
        return ["sudo", "zypper", "--non-interactive", "install", pkg]
    return ["sudo", pm or "pkg", "install", pkg]


def _cargo(pkg, family):
    """
    Install a Rust tool, bootstrapping rustup first when cargo is missing. The
    toolchain check, the rustup pull and the build all live in ONE shell step so
    cargo lands on PATH (via ~/.cargo/env) inside the same process the build runs
    in; the old split that ran "cargo install" as its own step never saw the fresh
    cargo on a bare box and failed.

    swww has no crate on crates.io, so it is special-cased to a source build off
    github: clone, cargo build --release, then drop both binaries (swww and the
    swww-daemon) into ~/.local/bin, which needs no root. Every other crate
    (matugen) keeps the plain cargo install.
    """
    crate = pkg["id"]
    if crate == "swww":
        return [
            {"desc": "no swww crate on crates.io, clone the source from github",
             "run": ["git", "clone", "https://github.com/LGFae/swww"]},
            {"desc": "make sure cargo is here, then build swww and swww-daemon (release)",
             "shell": _CARGO_PREP + "; cd swww && cargo build --release"},
            {"desc": "install both swww binaries into ~/.local/bin, no root needed",
             "shell": "mkdir -p %s && install -m755 "
                      "swww/target/release/swww swww/target/release/swww-daemon %s"
                      % (shlex.quote(BIN_DIR), shlex.quote(BIN_DIR))},
        ]
    return [
        {"desc": "make sure cargo is here, then build %s from crates.io" % crate,
         "shell": _CARGO_PREP + "; cargo install " + shlex.quote(crate)},
    ]


def _ghostty(pkg, family):
    """
    Ghostty the honest way. On fedora the fyralabs Terra repo ships it, so add
    that and install. Everywhere else there is no package, so build it from
    source with Zig, which the build pins hard (latest tags want Zig 0.14, the
    git tip wants 0.15.2).
    """
    if family == "fedora":
        return [
            {"desc": "add the fyralabs Terra repo, a third-party repo that ships ghostty for fedora",
             "shell": "sudo dnf install -y --nogpgcheck "
                      "--repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release"},
            {"desc": "install ghostty from Terra",
             "run": ["sudo", "dnf", "install", "-y", "ghostty"]},
        ]
    return [
        {"desc": "no ghostty package here, clone the source (the build needs the exact Zig it pins)",
         "run": ["git", "clone", "--depth", "1", "https://github.com/ghostty-org/ghostty"]},
        {"desc": "compile a release build with Zig",
         "shell": "cd ghostty && zig build -Doptimize=ReleaseFast"},
        {"desc": "install ghostty into /usr",
         "shell": "cd ghostty && sudo zig build -p /usr -Doptimize=ReleaseFast"},
    ]


def _dotool(pkg, family):
    """
    Build dotool from sourcehut, then wire up uinput. The build installs the
    binaries and the project's own 0620 udev rule, but that mode leaves an
    EACCES on /dev/uinput, so we drop in a 0660 rule and add the user to the
    input group, which is the fix the rice already runs on.
    """
    rule = ('KERNEL=="uinput", SUBSYSTEM=="misc", GROUP="input", '
            'MODE="0660", OPTIONS+="static_node=uinput"')
    return [
        {"desc": "no dotool package off arch, clone it from sourcehut",
         "run": ["git", "clone", "https://git.sr.ht/~geb/dotool"]},
        {"desc": "build the binaries (needs go, libxkbcommon-dev and scdoc)",
         "shell": "cd dotool && ./build.sh"},
        {"desc": "install dotool, dotoolc and dotoold plus the man page",
         "shell": "cd dotool && sudo ./build.sh install"},
        {"desc": "load the uinput module now and keep it loading on every boot",
         "shell": "sudo modprobe uinput && echo uinput | sudo tee /etc/modules-load.d/uinput.conf"},
        {"desc": "let the input group reach /dev/uinput at 0660, which cures the EACCES the 0620 rule leaves",
         "shell": "printf '%%s\\n' '%s' | sudo tee /etc/udev/rules.d/99-uinput.rules" % rule},
        {"desc": "create the input group if it is missing and add you to it",
         "shell": 'sudo groupadd -f input && sudo usermod -aG input "$(id -un)"'},
        {"desc": "reload udev so the new rule takes effect",
         "run": ["sudo", "udevadm", "control", "--reload"]},
        {"desc": "re-trigger udev for /dev/uinput",
         "run": ["sudo", "udevadm", "trigger"]},
    ]


def _fetch_unpack_shell(url, dest):
    """
    One shell line that downloads url into a fresh mktemp file, unpacks it into
    dest, then deletes the temp. mktemp gives an unpredictable name so nothing can
    sit on a known /tmp path and win a TOCTOU race against the download.
    """
    return ('a="$(mktemp --suffix=.tar.xz)" && '
            'curl -fsSL -o "$a" %s && tar -xf "$a" -C %s && rm -f "$a"'
            % (shlex.quote(url), shlex.quote(dest)))


def _nerdfont(pkg, family):
    """Pull the JetBrainsMono Nerd Font from the latest nerd-fonts release."""
    url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
    return [
        {"desc": "make sure the user font dir exists",
         "run": ["mkdir", "-p", FONT_DIR]},
        {"desc": "download the patched JetBrainsMono Nerd Font to a private temp file and unpack it",
         "shell": _fetch_unpack_shell(url, FONT_DIR)},
        {"desc": "rebuild the font cache so the glyphs show up",
         "run": ["fc-cache", "-f"]},
    ]


def _github(pkg, family):
    """Pull the Bibata-Modern-Classic cursor from the latest Bibata release."""
    url = ("https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/"
           "Bibata-Modern-Classic.tar.xz")
    return [
        {"desc": "make sure the user icon dir exists",
         "run": ["mkdir", "-p", ICON_DIR]},
        {"desc": "download the Bibata-Modern-Classic cursor theme to a private temp file and extract it",
         "shell": _fetch_unpack_shell(url, ICON_DIR)},
    ]


def _flatpak(pkg, family):
    """
    Make sure flatpak and flathub are set up, then install the app from there. The
    remote and the install are both --user, a per-user install that needs no root
    or polkit; a system-wide flatpak would stall waiting on an auth prompt the bare
    TTY install path can never answer.
    """
    app = pkg["flatpak_id"]
    return [
        {"desc": "make sure flatpak itself is installed",
         "run": _pm_install(family, "flatpak")},
        {"desc": "add the flathub remote for this user if it is not there already",
         "run": ["flatpak", "--user", "remote-add", "--if-not-exists", "flathub",
                 "https://flathub.org/repo/flathub.flatpakrepo"]},
        {"desc": "install %s from flathub for this user, no root needed" % app,
         "run": ["flatpak", "--user", "install", "-y", "flathub", app]},
    ]


def _curl(pkg, family):
    """Hand off to the project's own curl-pipe installer (rishot)."""
    return [
        {"desc": "run rishot's own installer",
         "shell": "curl -fsSL https://raw.githubusercontent.com/Gakuseei/rishot/main/install.sh | sh"},
    ]


_HANDLERS = {
    "cargo": _cargo,
    "ghostty": _ghostty,
    "dotool": _dotool,
    "nerdfont": _nerdfont,
    "github": _github,
    "flatpak": _flatpak,
    "curl": _curl,
}


def steps_for(fallback_id, pkg, family):
    """
    The ordered steps that get one package onto this family without a native
    package. Returns [] for an unknown fallback id so the caller can skip it.
    """
    handler = _HANDLERS.get(fallback_id)
    if handler is None:
        return []
    return handler(pkg, family)


def _selftest():
    m = load_manifest()
    seen = set()
    for pkg in m["packages"]:
        fb = pkg.get("fallback")
        if not fb:
            continue
        for fam in ("debian", "fedora"):
            steps = steps_for(fb, pkg, fam)
            assert steps, "%s on %s returned no steps" % (fb, fam)
            for s in steps:
                assert "desc" in s and ("run" in s or "shell" in s), \
                    "bad step for %s on %s: %r" % (fb, fam, s)
        seen.add(fb)

    # an unknown id gets no steps
    assert steps_for("nope", {}, "debian") == []

    # ghostty really branches on family: Terra on fedora, a Zig build elsewhere
    fed = steps_for("ghostty", {"id": "ghostty"}, "fedora")
    deb = steps_for("ghostty", {"id": "ghostty"}, "debian")
    assert any("terra" in s.get("shell", "").lower() for s in fed)
    assert any("zig build" in s.get("shell", "") for s in deb)

    # cargo bootstraps rustup and sources ~/.cargo/env in the same shell as the
    # build, so a plain crate is one step that ends in `cargo install <crate>`.
    matugen = steps_for("cargo", {"id": "matugen"}, "debian")
    assert len(matugen) == 1
    sh = matugen[0]["shell"]
    assert "rustup" in sh and '. "$HOME/.cargo/env"' in sh and sh.endswith("cargo install matugen")

    # swww is the special case: no crate, so clone LGFae/swww, build a release, and
    # install both the swww and swww-daemon binaries instead of cargo install.
    swww = steps_for("cargo", {"id": "swww"}, "debian")
    assert any("https://github.com/LGFae/swww" in s.get("run", []) for s in swww)
    assert any("cargo build --release" in s.get("shell", "") for s in swww)
    install_sh = next(s["shell"] for s in swww if "install -m755" in s.get("shell", ""))
    assert "swww/target/release/swww" in install_sh and "swww-daemon" in install_sh
    assert not any(s.get("run", [None])[0] == "cargo" for s in swww)

    # flatpak installs per-user so a bare TTY needs no root or polkit.
    flat = steps_for("flatpak", {"flatpak_id": "com.example.App"}, "debian")
    assert all("--user" in s["run"] for s in flat if s["run"][0] == "flatpak")

    print("fallbacks.py selftest: %d handlers, all return steps" % len(seen))


if __name__ == "__main__":
    _selftest()
