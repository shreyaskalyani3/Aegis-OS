#!/usr/bin/env python3
"""Isolated desktop/guest checks, with an opt-in transient user-service test."""
import configparser
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[2]
IMAGE = ROOT / "profile/airootfs"
USER_UNITS = IMAGE / "etc/skel/.config/systemd/user"


def unit(name):
    result = configparser.ConfigParser(interpolation=None, strict=False)
    result.read(USER_UNITS / name)
    return result


class SessionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="aegis-session-test-")
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.log = self.home / "calls"
        # Do not inherit credentials, a real session bus, or a user's HOME.
        self.env = {
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "HOME": str(self.home), "CALLS": str(self.log),
            "WAYLAND_DISPLAY": "wayland-test", "DISPLAY": ":91",
            "HYPRLAND_INSTANCE_SIGNATURE": "aegis-test",
            "XDG_CURRENT_DESKTOP": "Hyprland", "XDG_SESSION_TYPE": "wayland",
            "XDG_SESSION_DESKTOP": "Hyprland",
            "QT_QPA_PLATFORMTHEME": "qt5ct", "QT_QPA_PLATFORMTHEME_QT6": "qt6ct",
        }

    def mock(self, name, body="exit 0"):
        script = self.bin / name
        script.write_text(
            '#!/bin/bash\nprintf "%s %s\\n" "${0##*/}" "$*" >> "$CALLS"\n' + body + "\n",
            encoding="utf-8",
        )
        script.chmod(0o755)

    def run_script(self, name, **env):
        return subprocess.run(
            ["/bin/bash", str(IMAGE / "usr/local/bin" / name)],
            env={**self.env, **env}, text=True, capture_output=True, timeout=10,
        )

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def session_mocks(self):
        self.mock("dbus-update-activation-environment", 'exit "${DBUS_RC:-0}"')
        self.mock("systemctl", '''
if [[ "$*" == *import-environment* ]]; then
    sleep 0.05
    [[ "${IMPORT_RC:-0}" == 0 ]] || exit "$IMPORT_RC"
    touch "$HOME/import-complete"
elif [[ "$*" == *start* ]]; then
    test -f "$HOME/import-complete" || exit 99
fi
''')
        for name in ("qs", "awww-daemon", "aegis-desktop-setup", "aegis-welcome"):
            self.mock(name)

    def test_environment_import_finishes_before_services_start(self):
        self.session_mocks()
        result = self.run_script("aegis-session-start")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        imported = next(i for i, call in enumerate(calls) if "import-environment" in call)
        for expected in ("start aegis-session.target",):
            index = next(i for i, call in enumerate(calls) if expected in call)
            self.assertGreater(index, imported)
        self.assertTrue((self.home / "import-complete").exists())
        for name in ("DISPLAY", "WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE",
                     "QT_QPA_PLATFORMTHEME", "QT_QPA_PLATFORMTHEME_QT6"):
            self.assertIn(name, calls[imported].split())
        self.assertFalse(any(call.startswith("qs ") for call in calls))

    def test_dbus_failure_does_not_skip_systemd_import(self):
        self.session_mocks()
        result = self.run_script("aegis-session-start", DBUS_RC="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(any("start aegis-session.target" in c for c in self.calls()))

    def test_failed_import_never_starts_services_with_stale_environment(self):
        self.session_mocks()
        result = self.run_script("aegis-session-start", IMPORT_RC="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("environment import failed", result.stderr)
        self.assertTrue(any("import-environment" in c for c in self.calls()))
        self.assertFalse(any("systemctl --user start" in c for c in self.calls()))

    def test_non_graphical_invocation_is_rejected(self):
        self.session_mocks()
        result = self.run_script("aegis-session-start", WAYLAND_DISPLAY="")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no Wayland session", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_both_configs_use_one_ordered_session_entrypoint(self):
        hypr = IMAGE / "etc/skel/.config/hypr"
        for filename in ("startup.lua", "hyprland.conf"):
            with self.subTest(filename=filename):
                text = (hypr / filename).read_text()
                self.assertIn("aegis-session-start", text)
                for old in ("import-environment", "start graphical-session.target",
                            "start aphotic-shell.service", "awww-daemon",
                            "theme ensure-default"):
                    self.assertNotIn(old, text)

    def test_wallpaper_has_own_service_not_execstartpre_child(self):
        wallpaper = unit("aegis-wallpaper.service")
        self.assertEqual(wallpaper["Service"]["ExecStart"], "/usr/bin/awww-daemon")
        self.assertIn("graphical-session.target", wallpaper["Unit"]["PartOf"].split())
        first = unit("aegis-first-login.service")
        self.assertIn("aegis-wallpaper.service", first["Unit"]["After"].split())
        self.assertIn("aegis-wallpaper.service", first["Unit"]["Wants"].split())
        self.assertNotIn("awww-daemon", (IMAGE / "usr/local/bin/aegis-desktop-setup").read_text())

    def test_session_target_is_started_only_after_environment_import(self):
        target = unit("aegis-session.target")
        for name in ("aphotic-shell.service", "aegis-wallpaper.service",
                     "aegis-first-login.service", "aegis-vbox-session.service"):
            self.assertIn(name, target["Unit"]["Wants"].split())
        self.assertIn("graphical-session.target", target["Unit"]["PartOf"].split())
        # Hyprland starts the generic target itself. Pulling our helpers in
        # from that target would bypass the explicit environment barrier.
        for dropin in (USER_UNITS / "graphical-session.target.d").glob("*.conf"):
            self.assertNotIn("Wants=", dropin.read_text())

    def test_vbox_session_keeps_daemonized_clients_alive(self):
        vbox = unit("aegis-vbox-session.service")
        self.assertEqual(vbox["Service"]["Type"], "oneshot")
        self.assertEqual(vbox["Service"]["RemainAfterExit"], "yes")

    def test_recovery_tracks_its_detached_ui(self):
        recovery = unit("aphotic-recovery.service")
        self.assertEqual(recovery["Service"]["Type"], "exec")
        self.assertEqual(recovery["Service"]["ExitType"], "cgroup")
        self.assertEqual(recovery["Service"]["RemainAfterExit"], "no")

    def test_only_one_wallpaper_daemon_is_autostarted(self):
        for name in ("startup.lua", "hyprland.conf"):
            text = (IMAGE / "etc/skel/.config/hypr" / name).read_text()
            self.assertFalse("hyprpaper &" in text, f"{name} starts a competing wallpaper daemon")

    @unittest.skipUnless(os.environ.get("AEGIS_TEST_USER_SYSTEMD") == "1",
                         "opt in with AEGIS_TEST_USER_SYSTEMD=1 for a transient user-unit test")
    def test_real_systemd_retains_daemonized_child(self):
        # This optional check runs only a sleep process in a uniquely named
        # transient user unit. It never starts or changes the desktop services.
        launcher = self.home / "launcher.sh"
        pidfile = self.home / "child.pid"
        launcher.write_text('#!/bin/bash\n/usr/bin/sleep 30 &\nprintf "%s\\n" "$!" > "$1"\n')
        for source in ("aegis-vbox-session.service", "aphotic-recovery.service"):
            with self.subTest(source=source):
                name = "aegis-test-" + uuid.uuid4().hex + ".service"
                pidfile.unlink(missing_ok=True)
                service = unit(source)["Service"]
                try:
                    result = subprocess.run(
                        ["systemd-run", "--user", "--quiet", "--collect", "--unit=" + name,
                         "--property=Type=" + service["Type"],
                         "--property=ExitType=" + service.get("ExitType", "main"),
                         "--property=RemainAfterExit=" + service["RemainAfterExit"],
                         "--property=TimeoutStartSec=5", "--property=TimeoutStopSec=5",
                         "/bin/bash", str(launcher), str(pidfile)],
                        text=True, capture_output=True, timeout=15,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    for _ in range(20):
                        if pidfile.exists():
                            break
                        time.sleep(0.1)
                    time.sleep(0.1)
                    active = subprocess.run(
                        ["systemctl", "--user", "is-active", name],
                        text=True, capture_output=True, timeout=10,
                    )
                    self.assertEqual(active.stdout.strip(), "active", active.stderr)
                    os.kill(int(pidfile.read_text()), 0)
                finally:
                    subprocess.run(["systemctl", "--user", "stop", name],
                                   capture_output=True, timeout=10, check=False)

    @unittest.skipUnless(shutil.which("systemd-analyze"), "systemd-analyze unavailable")
    def test_systemd_dependency_graph(self):
        # Analyze copies, never install/start units on the host. Substitute
        # only executable commands (not dependency edges) because the desktop
        # binaries are available in the ISO, not necessarily on a test runner.
        fixtures = self.home / "units"
        fixtures.mkdir()
        for name in ("aegis-session.target", "aegis-wallpaper.service",
                     "aegis-first-login.service", "aphotic-shell.service",
                     "aphotic-recovery.service", "aegis-vbox-session.service"):
            text = (USER_UNITS / name).read_text()
            text = re.sub(r"(?m)^(Exec\w+)=.*$", r"\1=/usr/bin/true", text)
            (fixtures / name).write_text(text)
        result = subprocess.run(
            ["systemd-analyze", "--user", "--man=no", "verify", str(fixtures / "aegis-session.target")],
            env={**os.environ, "SYSTEMD_UNIT_PATH": f"{fixtures}:/usr/lib/systemd/user"},
            text=True, capture_output=True, timeout=20,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("ordering cycle", result.stderr.lower())

    def test_vm_service_selection_and_missing_optional_unit(self):
        self.mock("systemd-detect-virt", 'echo "$VIRT"; [[ "$VIRT" != none ]]')
        self.mock("systemctl", '[[ "$*" != "cat hv_fcopy_daemon.service" ]]')
        expected = {
            "oracle": ["vboxservice.service", "aegis-vbox-drm.service"],
            "vmware": ["vmtoolsd.service", "vmware-vmblock-fuse.service"],
            "kvm": ["qemu-guest-agent.service", "spice-vdagentd.service"],
            "qemu": ["qemu-guest-agent.service", "spice-vdagentd.service"],
            "microsoft": ["hv_kvp_daemon.service", "hv_vss_daemon.service"],
            "none": [], "docker": [],
        }
        for virt, units in expected.items():
            with self.subTest(virt=virt):
                self.log.write_text("")
                result = self.run_script("aegis-vm-guest-setup", VIRT=virt)
                self.assertEqual(result.returncode, 0, result.stderr)
                started = [c.removeprefix("systemctl start --no-block ") for c in self.calls()
                           if c.startswith("systemctl start ")]
                self.assertEqual(started, units)

    def test_firstboot_never_writes_to_removable_media(self):
        source = (IMAGE / "usr/local/bin/aegis-firstboot-cleanup").read_text()
        # Check before executing: even a failing regression must not touch a
        # real device or the host's /var/lib. Only the marker/guard paths below
        # are remapped; no destructive command is permitted in this helper.
        self.assertNotRegex(source, r"(?m)^\s*(?:if\s+!\s+)?(?:dd|wipefs|sgdisk|parted)\s")
        sandboxed = source.replace("/var/lib/aegis", str(self.home / "state"))
        sandboxed = sandboxed.replace("/run/archiso", str(self.home / "live"))
        for name in ("lsblk", "findmnt", "dd", "wipefs", "sgdisk", "parted"):
            self.mock(name, "exit 98")
        result = subprocess.run(["/bin/bash", "-c", sandboxed], env=self.env,
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [])
        marker = self.home / "state/firstboot-cleanup-done"
        self.assertTrue(marker.exists())
        result = subprocess.run(["/bin/bash", "-c", sandboxed], env=self.env,
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        marker.unlink()
        (self.home / "live").mkdir()
        result = subprocess.run(["/bin/bash", "-c", sandboxed], env=self.env,
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0)
        self.assertFalse(marker.exists())


class BuildDefaultsTests(unittest.TestCase):
    def validate(self, **overrides):
        return subprocess.run(
            ["/bin/bash", "-c", 'source "$1"; validate_config', "_", str(ROOT / "scripts/lib/common.sh")],
            env={"PATH": "/usr/bin:/bin", "HOME": "/nonexistent", **overrides},
            text=True, capture_output=True, timeout=10,
        )

    def test_valid_live_default_overrides(self):
        result = self.validate(AEGIS_HOSTNAME="test-workstation", AEGIS_LIVE_USER="live-test",
                               AEGIS_LOCALE="de_DE.UTF-8", AEGIS_KEYMAP="de",
                               AEGIS_TIMEZONE="Europe/Berlin")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_invalid_hostname_and_password_lines_are_rejected(self):
        for overrides in ({"AEGIS_HOSTNAME": "bad host"}, {"AEGIS_HOSTNAME": "bad/host"},
                          {"AEGIS_LIVE_PASSWORD": "test\nline"},
                          {"AEGIS_ROOT_PASSWORD": "test\rline"}):
            with self.subTest(variable=next(iter(overrides))):
                result = self.validate(**overrides)
                self.assertNotEqual(result.returncode, 0)

    def test_build_stamps_actual_nondefault_live_configuration(self):
        build = (ROOT / "scripts/build-iso.sh").read_text()
        # Execute the real, bounded staging section, never the package manager
        # or the ISO build. This catches drift that copied shell snippets miss.
        section = build.split("# Materialize the non-secret live defaults", 1)[1]
        section = "# Materialize the non-secret live defaults" + section.split("# Prove it parses back", 1)[0]
        with tempfile.TemporaryDirectory(prefix="aegis-defaults-test-") as tmp:
            staged = Path(tmp)
            etc = staged / "airootfs/etc"
            (etc / "aegis").mkdir(parents=True)
            (etc / "environment").write_text("LANG=en_US.UTF-8\nKEYMAP=us\nQT_QPA_PLATFORMTHEME=qt6ct\n")
            values = {"AEGIS_HOSTNAME": "test-live", "AEGIS_TIMEZONE": "Europe/Berlin",
                      "AEGIS_LOCALE": "de_DE.UTF-8", "AEGIS_KEYMAP": "de"}
            result = subprocess.run(
                ["/bin/bash", "-c", "set -euo pipefail\n" + section],
                env={"PATH": "/usr/bin:/bin", "STAGED_PROFILE": tmp, **values},
                text=True, capture_output=True, timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((etc / "hostname").read_text(), "test-live\n")
            self.assertEqual((etc / "timezone").read_text(), "Europe/Berlin\n")
            self.assertEqual((etc / "locale.conf").read_text(), "LANG=de_DE.UTF-8\n")
            self.assertIn("KEYMAP=de\n", (etc / "vconsole.conf").read_text())
            self.assertEqual((etc / "environment").read_text(),
                             "LANG=de_DE.UTF-8\nKEYMAP=de\nQT_QPA_PLATFORMTHEME=qt6ct\n")
            result = subprocess.run(
                ["/bin/bash", "-c", 'source "$1"; printf "%s\\n" "$AEGIS_HOSTNAME" "$AEGIS_TIMEZONE" "$AEGIS_LOCALE" "$AEGIS_KEYMAP"',
                 "_", str(etc / "aegis/live.conf")],
                env={"PATH": "/usr/bin:/bin"}, text=True, capture_output=True, timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.splitlines(), list(values.values()))


if __name__ == "__main__":
    unittest.main(verbosity=2)
