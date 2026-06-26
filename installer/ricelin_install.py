#!/usr/bin/env python3
"""
The Ricelin installer orchestrator: the thin top layer that ties distro
detection, the package planner, the fallback handlers, the config deploy and the
terminal UI into one real install flow.

It only sequences and runs; every decision lives in the modules it imports.
distro.py says what to do with each package, pkg.py builds the argv that does it,
fallbacks.py describes the from-source work, deploy.py moves the configs, tui.py
draws the prompts. This file just walks them in order, asks the user the few
questions that matter, runs each step fail-soft (one bad package never aborts the
rest), and prints a report at the end.

--dry-run walks the whole flow and changes nothing: every command prints as
`would run: ...` and the deploy runs with apply=False. That is the primary test
path and is meant to work headless. --quickstart skips the wizard and takes the
Quick-profile defaults, so it pairs with --dry-run for a non-interactive check.
"""
import argparse
import os
import shlex
import shutil
import subprocess
import threading
from pathlib import Path

import deploy
import distro
import fallbacks
import grub_theme
import pkg
import tui


def _run(argv, dry, env=None):
    """
    Run one command, or print it as `would run:` under a dry run. Returns
    (ok, detail); detail carries the failure text the report turns into a hint.
    A missing binary or a non-zero exit is a soft failure, never a raise, so the
    install keeps going past a single bad step.
    """
    printable = " ".join(shlex.quote(a) for a in argv)
    if dry:
        print(f"  would run: {printable}")
        return True, ""
    runenv = None
    if env:
        runenv = dict(os.environ)
        runenv.update(env)
    try:
        result = subprocess.run(argv, env=runenv)
    except OSError as exc:
        return False, f"{exc}: {printable}"
    if result.returncode != 0:
        return False, f"exit {result.returncode}: {printable}"
    return True, ""


def _shell(cmd, dry):
    """Run a shell step (a pipe or a redirect), or print it under a dry run."""
    if dry:
        print(f"  would run: {cmd}")
        return True, ""
    try:
        result = subprocess.run(["sh", "-c", cmd])
    except OSError as exc:
        return False, f"{exc}: {cmd}"
    if result.returncode != 0:
        return False, f"exit {result.returncode}: {cmd}"
    return True, ""


def _compositor():
    """The running Wayland session, read off the environment the rice sets."""
    if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        return "Hyprland"
    if os.environ.get("NIRI_SOCKET"):
        return "Niri"
    return os.environ.get("XDG_CURRENT_DESKTOP") or "Unknown"


def _bootloader():
    """
    The boot loader in use, so the GRUB theme prompt only shows on a GRUB box.
    Spotted by the config the loader leaves on disk, with its tool on PATH as the
    backup signal.
    """
    if os.path.isfile("/boot/grub/grub.cfg") or shutil.which("grub-mkconfig"):
        return "grub"
    if os.path.isdir("/boot/loader/entries") or shutil.which("bootctl"):
        return "systemd-boot"
    if (os.path.isfile("/boot/limine.conf")
            or os.path.isfile("/boot/limine/limine.conf") or shutil.which("limine")):
        return "limine"
    return "other"


def _has_display_manager():
    """True when a login manager is set up, so the SDDM theme prompt makes sense."""
    if os.path.exists("/etc/systemd/system/display-manager.service"):
        return True
    return any(shutil.which(dm) for dm in ("sddm", "gdm", "lightdm", "ly", "greetd"))


def _active(unit):
    """Read-only check whether a systemd unit is active right now."""
    try:
        return subprocess.run(["systemctl", "is-active", "--quiet", unit]).returncode == 0
    except OSError:
        return False


def detect():
    """Read the whole machine state the flow branches on into one dict."""
    family = distro.detect_family()
    return {
        "family": family,
        "pretty": distro.detect_pretty(),
        "compositor": _compositor(),
        "pm": distro.PM.get(family, "Unknown"),
        "aur_helper": pkg.aur_helper(),
        "existing": deploy.detect_existing(),
        "bootloader": _bootloader(),
        "init": distro.detect_init(),
        "immutable": distro.is_immutable(),
    }


def _default_choices(args, info, manifest):
    """The non-interactive choices for --quickstart and the no-terminal fallback."""
    full_ids = {p["id"] for p in manifest["packages"] if p.get("group") == "full"}
    profile = "full" if args.full else "quick"
    return {
        "profile": profile,
        "aur_choice": info["aur_helper"] or "yay",
        "optional_ids": set(full_ids) if profile == "full" else set(),
        "sddm": args.sddm,
        "grub": False,
        "fish": True,
        "brave": args.brave,
    }


def _wizard(args, info, manifest):
    """
    Walk the few questions that shape the install. Raises RuntimeError up from the
    UI when there is no controlling terminal, so the caller can drop to defaults.
    """
    family = info["family"]

    pidx = tui.select_one("Install profile", [
        ("Quick", "Core rice, sensible defaults, no questions", True),
        ("Full", "Everything, plus the daily apps", False),
        ("Custom", "Walk every choice yourself", False),
    ], default=1 if args.full else 0)
    profile = ("quick", "full", "custom")[pidx]

    aur_choice = "yay"
    if family == "arch":
        aidx = tui.select_one("AUR helper", [
            ("yay", "Build AUR packages with yay", True),
            ("paru", "Build AUR packages with paru", False),
            ("None", "Skip the AUR, use fallbacks instead", False),
        ], default=0)
        aur_choice = ("yay", "paru", "none")[aidx]

    full_pkgs = [p for p in manifest["packages"] if p.get("group") == "full"]
    optional_ids = set()
    if profile in ("full", "custom"):
        options = [(p["id"], p["desc"], False) for p in full_pkgs]
        preselect = range(len(full_pkgs)) if profile == "full" else ()
        chosen = tui.select_many("Optional apps", options, preselect=preselect)
        optional_ids = {full_pkgs[i]["id"] for i in chosen}

    sddm = True if args.sddm else False
    if not args.sddm and _has_display_manager():
        sddm = tui.confirm("SDDM login theme", [
            "Install the torii SDDM login theme. (Recommended)",
            "A system change that needs sudo.",
        ])

    grub = False
    if info["bootloader"] == "grub":
        grub = tui.confirm("GRUB theme", [
            "Install the Ricelin GRUB theme.",
            "Theme only, it does not touch your boot entries.",
        ])

    brave = True if args.brave else False
    if not args.brave:
        bidx = tui.select_one("Brave browser", [
            ("Install Brave", "Brave browser with the matching Ricelin theme", True),
            ("Skip", "Leave Brave out for now", False),
        ], default=1)
        brave = bidx == 0

    fish = tui.confirm("Login shell", ["Set fish as your login shell. (Recommended)"])

    return {
        "profile": profile, "aur_choice": aur_choice, "optional_ids": optional_ids,
        "sddm": sddm, "grub": grub, "fish": fish, "brave": brave,
    }


def _build_plan(manifest, info, choices):
    """
    Resolve the chosen groups into concrete batches. Native packages already on
    the box are dropped (idempotent); the AUR ones, the repos to enable and the
    fallbacks are kept. Returns the split lists the runner walks.
    """
    family = info["family"]
    by_id = {p["id"]: p for p in manifest["packages"]}
    profile = choices["profile"]
    groups = ("core",) if profile == "quick" else ("core", "full")
    rows = distro.plan(manifest, family, groups, choices["aur_choice"])
    if profile != "quick":
        optional = choices["optional_ids"]
        rows = [r for r in rows if r["group"] == "core" or r["id"] in optional]

    repos, native, aur, fb, skipped = [], [], [], [], []
    for r in rows:
        if r["action"] == "skip":
            continue
        if r["action"] == "fallback":
            fb.append((r["id"], r["target"], by_id[r["id"]]))
            continue
        if pkg.is_installed(r["target"], family):
            skipped.append(r["id"])
            continue
        if r["repo"] and r["repo"] not in repos:
            repos.append(r["repo"])
        (aur if r["aur"] else native).append(r["target"])
    return {"repos": repos, "native": native, "aur": aur, "fallbacks": fb, "skipped": skipped}


def _aur_install_argv(names, family, aur_choice):
    """
    The unwrapped AUR-helper install command (the helper self-escalates, so sudo
    would break makepkg). Falls back to the chosen helper name when none is on
    PATH yet, so a dry run can print the line before the helper is bootstrapped.
    """
    if pkg.aur_helper():
        return pkg.install_argv(names, family, aur=True)
    helper = aur_choice if aur_choice in ("yay", "paru") else "yay"
    return [helper, "-S", "--needed", "--noconfirm", *names]


def _service_note(init):
    """The manual service commands for a non-systemd init, printed not run."""
    cmds = {
        "openrc": ["sudo rc-update add NetworkManager default && sudo rc-service NetworkManager start",
                   "sudo rc-update add bluetoothd default && sudo rc-service bluetoothd start"],
        "runit": ["sudo ln -s /etc/sv/NetworkManager /var/service",
                  "sudo ln -s /etc/sv/bluetoothd /var/service"],
        "dinit": ["sudo dinitctl enable NetworkManager", "sudo dinitctl enable bluetoothd"],
        "s6": ["s6-rc -u change NetworkManager", "s6-rc -u change bluetoothd"],
    }
    lines = ["Non-systemd init detected, enable the services yourself:"]
    lines += cmds.get(init, ["Enable NetworkManager and bluetooth with your init's tools."])
    return lines


def sudo_keepalive():
    """
    Ask for the password once, then keep the sudo timestamp warm in the
    background so no later step prompts again. Returns a stop callback the runner
    calls when the install is done.
    """
    subprocess.run(["sudo", "-v"])
    stop = threading.Event()

    def _loop():
        while not stop.wait(60):
            subprocess.run(["sudo", "-n", "-v"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    threading.Thread(target=_loop, daemon=True).start()
    return stop.set


def _summary_lines(info, choices, plan, args, do_pkgs):
    """The go/no-go summary the Ready confirm shows."""
    lines = []
    if not do_pkgs:
        lines.append("Skipping packages, deploying configs only.")
    else:
        count = len(plan["native"]) + len(plan["aur"]) + len(plan["fallbacks"])
        lines.append(f"Install {count} packages ({len(plan['skipped'])} already present).")
        if plan["repos"]:
            lines.append("Enable repos: " + ", ".join(plan["repos"]) + ".")
        if plan["fallbacks"]:
            names = ", ".join(sorted({h for _, h, _ in plan["fallbacks"]}))
            lines.append("Build via fallback: " + names + ".")
    if choices["sddm"]:
        lines.append("Install the torii SDDM login theme.")
    if choices["grub"]:
        lines.append("Install the GRUB theme.")
    if choices["brave"]:
        lines.append("Install Brave with the matching Ricelin theme.")
    if choices["fish"]:
        lines.append("Set fish as your login shell.")
    lines.append("Back up and deploy the Ricelin config.")
    return lines


def seed_wallpapers(dry):
    """
    Give a fresh box a wallpaper to show. Every wallpaper consumer reads
    ~/Ricelin/wallpapers (wallpaper.sh, the picker, the search, the palette), but
    that dir is gitignored and untracked, so a clone ships none: no background, an
    empty picker, the palette never fires. Create the dir plus the downloads
    subfolder and the ricelin cache, and when it holds no images yet, copy the
    tracked starter set in so swww, the picker and the palette all light up.
    """
    home = Path.home()
    wp = home / "Ricelin" / "wallpapers"
    starters = Path(__file__).resolve().parent / "starter-wallpapers"
    if dry:
        print("  would seed wallpapers -> ~/Ricelin/wallpapers")
        return
    (wp / "downloads").mkdir(parents=True, exist_ok=True)
    (home / ".cache" / "ricelin").mkdir(parents=True, exist_ok=True)
    exts = (".jpg", ".jpeg", ".png")
    has_image = any(p.is_file() and p.suffix.lower() in exts for p in wp.iterdir())
    if has_image:
        print(f"  wallpapers already present -> {wp}")
        return
    if not starters.is_dir():
        print(f"  no starter wallpapers to seed at {starters}")
        return
    seeded = 0
    for src in sorted(starters.iterdir()):
        if src.is_file() and src.suffix.lower() in exts:
            shutil.copy2(src, wp / src.name)
            seeded += 1
    print(f"  seeded {seeded} starter wallpaper(s) -> {wp}")


def bridge_wallpaper_binary(dry):
    """
    Point the rice's awww binary at swww. The wallpaper scripts call awww and
    awww-daemon (the CachyOS names); the manifest installs the `swww` package,
    which is real awww on CachyOS but plain swww/swww-daemon everywhere else
    (vanilla Arch, Fedora, openSUSE, a Debian source build). On those boxes no
    awww binary exists, so the wallpaper never sets. When awww is missing but
    swww is present, symlink the awww names onto swww in ~/.local/bin. A no-op
    where awww is the real binary. Returns (ok, detail, bridged) so the caller
    folds it into record() and flags the PATH note only when a link was made.
    """
    if dry:
        print("  would bridge: awww -> swww")
        return True, "", False
    if shutil.which("awww"):
        return True, "", False
    swww = shutil.which("swww")
    if not swww:
        return True, "", False
    pairs = [("awww", swww)]
    swww_daemon = shutil.which("swww-daemon")
    if swww_daemon:
        pairs.append(("awww-daemon", swww_daemon))
    bindir = Path.home() / ".local" / "bin"
    try:
        bindir.mkdir(parents=True, exist_ok=True)
        for name, target in pairs:
            link = bindir / name
            if link.is_symlink() or link.exists():
                link.unlink()
            link.symlink_to(target)
    except OSError as exc:
        return False, f"{exc}: bridge awww -> swww", False
    print(f"  bridged: awww -> {swww} (in {bindir})")
    return True, "", True


def deploy_brave_theme(source, dry):
    """
    Copy the bundled Brave theme into ~/.config/ricelin so the user can point
    Brave at it. Chromium signs its own preferences, so the theme can never be
    applied reliably from outside; it just has to sit on disk, ready to load from
    brave://settings. Returns (ok, detail) so the caller folds it into record().
    """
    dest_show = "~/.config/ricelin/brave-theme"
    if dry:
        print(f"  would deploy: brave-theme -> {dest_show}")
        return True, ""
    src = os.path.join(source, "brave-theme")
    if not os.path.isdir(src):
        return False, f"brave theme not found at {src}"
    dest = os.path.expanduser(dest_show)
    try:
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copytree(src, dest, dirs_exist_ok=True)
    except OSError as exc:
        return False, f"{exc}: copy brave-theme"
    print(f"  deployed: brave-theme -> {dest_show}")
    return True, ""


def _report(plan, failures, notes, info, choices, args, do_pkgs, dry):
    """The closing report: what landed, what was skipped, what failed, what's next."""
    verb = "Would install" if dry else "Installed"
    lines = []
    if do_pkgs:
        landed = plan["native"] + plan["aur"]
        if landed:
            lines.append(f"{verb}: " + ", ".join(landed))
        if plan["fallbacks"]:
            lines.append(f"{verb} via fallback: " + ", ".join(f for f, _, _ in plan["fallbacks"]))
        if plan["skipped"]:
            lines.append("Already present: " + ", ".join(plan["skipped"]))
    if notes:
        lines.extend(notes)
    tui.info(lines or ["No packages to install, configs only."])

    if failures:
        flines = ["Some steps did not finish:"]
        for step, _detail, hint in failures:
            flines.append(f"{step} -> {hint}")
        flines.append("Everything else went in; re-run to retry just these.")
        tui.info(flines)

    nxt = []
    if dry:
        nxt.append("Dry run, nothing changed. A real run finishes like this:")
    else:
        nxt.append("Everything is installed and the Ricelin config is deployed.")
    nxt.append("Log out and back in. The input group from uinput and the fish "
               "shell change both need a fresh login to take hold.")
    if info["init"] != "systemd" and do_pkgs:
        nxt.append("Enable NetworkManager and bluetooth with your init first "
                   "(the commands are listed above).")
    nxt.append("Then, from a TTY, start the compositor with: Hyprland")
    nxt.append("A starter wallpaper is set. Press Super+C to pick another or "
               "download more.")
    if choices["brave"]:
        nxt.append("Brave is installed. Open brave://settings/appearance and load "
                   "the Ricelin theme from ~/.config/ricelin/brave-theme.")
    tui.info(nxt)
    tui.outro("Dry run complete, nothing was changed" if dry else "Ricelin is in")


def run(args):
    """Walk the whole install flow and return an exit code."""
    dry = args.dry_run
    manifest = distro.load_manifest()
    info = detect()
    family_ok = info["family"] in distro.FAMILIES
    do_pkgs = not args.no_deps and family_ok

    tui.banner()
    helper = info["aur_helper"]
    if helper:
        helper_label = helper
    elif info["family"] == "arch":
        helper_label = "Will install yay"
    else:
        helper_label = "Not needed"
    has_config = any(v["exists"] for v in info["existing"].values())
    tui.detected([
        ("OS", info["pretty"], True),
        ("Session", info["compositor"], True),
        ("Packages", info["pm"], True),
        ("AUR helper", helper_label, True),
        ("Configs", "Found" if has_config else "Fresh machine", True),
    ])

    if args.quickstart:
        choices = _default_choices(args, info, manifest)
    else:
        try:
            choices = _wizard(args, info, manifest)
        except RuntimeError:
            tui.info(["No controlling terminal, taking the Quick defaults."])
            choices = _default_choices(args, info, manifest)

    plan = _build_plan(manifest, info, choices)

    if not family_ok and not args.no_deps:
        tui.info([f"Unsupported distro family ({info['pretty']}), "
                  "skipping packages and deploying configs only."])

    summary = _summary_lines(info, choices, plan, args, do_pkgs)
    if args.quickstart:
        tui.info(summary)
    else:
        try:
            if not tui.confirm("Ready", summary):
                tui.outro("Cancelled")
                return 0
        except RuntimeError:
            tui.info(summary)

    failures, notes = [], []

    def record(ok, detail, step, hint):
        if not ok:
            failures.append((step, detail, hint))

    needs_sudo = (do_pkgs or choices["sddm"] or choices.get("grub")) and not dry
    keepalive_stop = sudo_keepalive() if needs_sudo else None
    try:
        if do_pkgs:
            family = info["family"]

            # a. refresh the package index first so a stale list never sinks the run.
            refresh_env = pkg.INSTALL_ENV if family == "debian" else None
            ok, detail = _run(pkg.refresh_argv(family), dry, env=refresh_env)
            record(ok, detail, "Refresh package index",
                   "Update the package list yourself, then re-run.")

            # b. bootstrap an AUR helper on Arch when one is wanted but missing.
            if family == "arch" and choices["aur_choice"] != "none" and pkg.aur_helper() is None:
                for step_argv in pkg.ensure_aur_helper_steps():
                    ok, detail = _run(step_argv, dry)
                    record(ok, detail, "Bootstrap yay",
                           "Install yay or paru by hand, then re-run.")

            # c. enable any extra repos the native packages need.
            for repo in plan["repos"]:
                for argv in pkg.enable_repo_argv(repo, family):
                    ok, detail = _run(pkg.privileged(argv, family), dry)
                    record(ok, detail, f"Enable repo {repo}",
                           "Enable the repo by hand, then re-run.")

            # d. the native batch, one install, sudo-wrapped. If the whole
            #    transaction aborts on a single bad name, retry each package
            #    alone so one failure never loses the family's core set.
            if plan["native"]:
                batch = pkg.install_argv(plan["native"], family)
                if family == "fedora":
                    batch = [*batch, "--skip-broken"]
                ok, detail = _run(pkg.privileged(batch, family), dry, env=pkg.INSTALL_ENV)
                if ok or dry:
                    record(ok, detail, "Install packages",
                           "Re-run; a single failed package will not block the rest.")
                else:
                    for name in plan["native"]:
                        argv = pkg.privileged(pkg.install_argv([name], family), family)
                        ok, detail = _run(argv, dry, env=pkg.INSTALL_ENV)
                        record(ok, detail, f"Install {name}",
                               "Install this one package by hand, then re-run.")

            # e. the AUR batch, unwrapped, the helper escalates itself. Same
            #    per-package retry on a batch abort.
            if plan["aur"]:
                argv = _aur_install_argv(plan["aur"], family, choices["aur_choice"])
                ok, detail = _run(argv, dry)
                if ok or dry:
                    record(ok, detail, "Install AUR packages",
                           "Build the AUR packages with your helper, then re-run.")
                else:
                    for name in plan["aur"]:
                        one = _aur_install_argv([name], family, choices["aur_choice"])
                        ok, detail = _run(one, dry)
                        record(ok, detail, f"Install AUR {name}",
                               "Build this AUR package by hand, then re-run.")

            # f. the fallbacks, each handler's steps in order.
            for fid, handler, pkgdict in plan["fallbacks"]:
                for step in fallbacks.steps_for(handler, pkgdict, family):
                    if "run" in step:
                        ok, detail = _run(step["run"], dry)
                    else:
                        ok, detail = _shell(step["shell"], dry)
                    record(ok, detail, f"Fallback {fid} ({handler})",
                           "Follow the project's own install steps for this one.")

            # g. wire up uinput on every family, the dotool handler's last steps.
            #    Skipped only when the dotool fallback already ran them (off Arch),
            #    so uinput ends up set up everywhere with no double work.
            dotool_fb = any(handler == "dotool" for _, handler, _ in plan["fallbacks"])
            if not dotool_fb:
                for step in fallbacks.steps_for("dotool", {"id": "dotool"}, family)[3:]:
                    if "run" in step:
                        ok, detail = _run(step["run"], dry)
                    else:
                        ok, detail = _shell(step["shell"], dry)
                    record(ok, detail, "Set up uinput",
                           "Add yourself to the input group and reload udev by hand.")

            # h. services: enable on systemd, print the manual commands otherwise.
            if info["init"] == "systemd":
                if _active("systemd-networkd") or _active("iwd"):
                    notes.append("Another network manager is active, left NetworkManager "
                                 "alone. The Link surface wants NetworkManager.")
                else:
                    ok, detail = _run(
                        ["sudo", "systemctl", "enable", "--now", "NetworkManager.service"], dry)
                    record(ok, detail, "Enable NetworkManager",
                           "Enable NetworkManager.service yourself.")
                ok, detail = _run(
                    ["sudo", "systemctl", "enable", "--now", "bluetooth.service"], dry)
                record(ok, detail, "Enable bluetooth", "Enable bluetooth.service yourself.")
            else:
                notes.extend(_service_note(info["init"]))

        # i. bridge the wallpaper binary onto swww when the rice's awww name is
        #    missing, so the background sets on every family, not just CachyOS.
        ok, detail, bridged = bridge_wallpaper_binary(dry)
        record(ok, detail, "Bridge wallpaper binary",
               "Symlink ~/.local/bin/awww to $(command -v swww) yourself.")
        if bridged:
            notes.append("Linked awww to swww in ~/.local/bin. Make sure "
                         "~/.local/bin is on PATH so the wallpaper script finds it.")

        # j. fish as the login shell, kept even with --no-deps.
        if choices["fish"]:
            fishbin = shutil.which("fish") or "/usr/bin/fish"
            ok, detail = _run(["chsh", "-s", fishbin], dry)
            record(ok, detail, "Set fish as login shell",
                   "Run: chsh -s $(command -v fish)")

        # k. deploy the configs and make them portable. A copytree or write
        #    that hits an OSError mid-iteration is recorded and stepped past,
        #    so a real run still finishes with a report instead of a traceback.
        try:
            for action in deploy.deploy(src=args.source, config_root=deploy.CONFIG_ROOT,
                                        apply=not dry):
                if action["action"] == "skip":
                    print(f"  deploy skip: {action['item']} ({action.get('reason', '')})")
                    continue
                head = "would deploy" if dry else "deployed"
                extra = f" (backup {action['backup']})" if action.get("backup") else ""
                print(f"  {head}: {action['item']} -> {action['dest']}{extra}")
        except OSError as exc:
            record(False, str(exc), "Deploy configs",
                   "Check ~/.config permissions and re-run the installer.")
        try:
            for action in deploy.neutralize(config_root=deploy.CONFIG_ROOT, apply=not dry):
                head = "would neutralize" if dry else "neutralized"
                print(f"  {head}: {action['step']}")
        except OSError as exc:
            record(False, str(exc), "Neutralize configs",
                   "Check ~/.config permissions and re-run the installer.")

        # l. seed a starter wallpaper so the first boot has a background, a
        #    populated picker and a palette to render.
        seed_wallpapers(dry)

        # m. themes.
        if choices["sddm"]:
            sddm_installer = os.path.join(args.source, "sddm", "themes", "torii", "install.sh")
            if os.path.isfile(sddm_installer):
                ok, detail = _run(["sh", sddm_installer], dry)
                record(ok, detail, "Install SDDM theme",
                       "Run the SDDM theme installer by hand.")
            else:
                notes.append(f"SDDM installer not found at {sddm_installer}, skipped.")
        if choices["grub"] and info["bootloader"] == "grub":
            for action in grub_theme.apply(args.source, dry):
                if dry:
                    printable = " ".join(shlex.quote(a) for a in action["cmd"])
                    print(f"  would run: {printable}")
                else:
                    record(action["ok"], action["detail"], "Install GRUB theme",
                           "Run the GRUB theme steps by hand.")

        # n. optional Brave: install it through the same resolve/fallback path the
        #    core packages use (arch -> AUR brave-bin, off arch -> Flathub), then
        #    drop the theme files in place. The theme is never auto-applied, since
        #    Chromium signs its prefs; the user loads it from brave://settings.
        if choices["brave"]:
            if do_pkgs:
                family = info["family"]
                brave_pkg = next(p for p in manifest["packages"] if p["id"] == "brave")
                action, target = distro.resolve(brave_pkg, family, choices["aur_choice"])
                if action == "skip":
                    notes.append("No Brave package for this distro, skipped the install.")
                elif action == "fallback":
                    for step in fallbacks.steps_for(target, brave_pkg, family):
                        if "run" in step:
                            ok, detail = _run(step["run"], dry)
                        else:
                            ok, detail = _shell(step["shell"], dry)
                        record(ok, detail, "Install Brave",
                               "Install Brave by hand, then load its theme.")
                elif pkg.is_installed(target, family):
                    notes.append("Brave is already installed.")
                elif distro.is_aur(brave_pkg, family):
                    ok, detail = _run(
                        _aur_install_argv([target], family, choices["aur_choice"]), dry)
                    record(ok, detail, "Install Brave",
                           "Install Brave by hand, then load its theme.")
                else:
                    argv = pkg.privileged(pkg.install_argv([target], family), family)
                    ok, detail = _run(argv, dry, env=pkg.INSTALL_ENV)
                    record(ok, detail, "Install Brave",
                           "Install Brave by hand, then load its theme.")
            else:
                notes.append("Skipped the Brave install, only deployed its theme.")
            ok, detail = deploy_brave_theme(args.source, dry)
            record(ok, detail, "Deploy Brave theme",
                   "Copy configs/brave-theme to ~/.config/ricelin/brave-theme yourself.")
    finally:
        if keepalive_stop:
            keepalive_stop()

    _report(plan, failures, notes, info, choices, args, do_pkgs, dry)
    return 0


def main():
    parser = argparse.ArgumentParser(
        description="Install the Ricelin Hyprland rice across distro families.")
    parser.add_argument("--dry-run", action="store_true",
                        help="Walk the whole flow and change nothing")
    parser.add_argument("--quickstart", action="store_true",
                        help="Skip the wizard, take the Quick-profile defaults")
    parser.add_argument("--source", default=str(deploy.CONFIGS),
                        help="The repo configs directory to deploy from")
    parser.add_argument("--full", action="store_true",
                        help="Preselect the Full profile")
    parser.add_argument("--sddm", action="store_true",
                        help="Preselect the torii SDDM login theme")
    parser.add_argument("--brave", action="store_true",
                        help="Preselect Brave plus its Ricelin theme")
    parser.add_argument("--no-deps", action="store_true",
                        help="Skip the package step, only deploy the configs")
    args = parser.parse_args()
    try:
        return run(args)
    except KeyboardInterrupt:
        tui.outro("Cancelled")
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
