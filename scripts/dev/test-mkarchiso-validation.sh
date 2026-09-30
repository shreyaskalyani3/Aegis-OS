#!/usr/bin/env bash
# =============================================================================
#  test-mkarchiso-validation.sh — verify mkarchiso's boot-package validation
#  passes against a profile copy, replicating its exact parse + membership
#  check (sed parse + " ${pkg_list[*]} " =~ ' <pkg> '). Run in WSL as root.
# =============================================================================
set -e

REPLICA=/root/aegis-mktest
mkdir -p "$REPLICA"
rm -rf "$REPLICA/profile"
cp -a /root/AegisOS/profile "$REPLICA/profile"
cd "$REPLICA/profile"

mapfile -t pkgs < <(sed '/^[[:blank:]]*#.*/d;s/#.*//;/^[[:blank:]]*$/d' packages.x86_64)
echo "pkg count: ${#pkgs[@]}"

ok=1
for want in syslinux memtest86+ edk2-shell memtest86+-efi grub efibootmgr os-prober; do
    if [[ ! " ${pkgs[*]} " =~ " $want " ]]; then
        echo "  $want: MISSING (mkarchiso would fail)"
        ok=0
    else
        echo "  $want: ok"
    fi
done

[[ $ok -eq 1 ]] && echo "MKARCHISO-VALIDATION-PASS"
rm -rf "$REPLICA"
