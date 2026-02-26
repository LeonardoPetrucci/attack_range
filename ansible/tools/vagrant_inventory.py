#!/usr/bin/env python3
"""Generate ansible/inventory.ini from running Vagrant machines (Hyper-V)."""
import subprocess, sys, re, pathlib, json

vagrant_dir = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path('../vagrant')

res = subprocess.run(
    ['vagrant', 'status', '--machine-readable'],
    cwd=vagrant_dir, capture_output=True, text=True, check=True
)

machines = []
for line in res.stdout.splitlines():
    parts = line.split(',')
    if len(parts) >= 4 and parts[2] == 'state' and parts[3] == 'running':
        machines.append(parts[1])

if not machines:
    print('[warn] No running VMs. Run vagrant up first.')
    sys.exit(0)

lines = ['[range]']
for m in machines:
    r = subprocess.run(
        ['vagrant', 'ssh-config', m],
        cwd=vagrant_dir, capture_output=True, text=True, check=True
    )
    cfg = r.stdout
    host_match = re.search(r'^\s*HostName\s+(\S+)', cfg, re.M)
    port_match = re.search(r'^\s*Port\s+(\S+)',     cfg, re.M)
    user_match = re.search(r'^\s*User\s+(\S+)',     cfg, re.M)
    key_match  = re.search(r'^\s*IdentityFile\s+(.+)', cfg, re.M)
    if not all([host_match, port_match, user_match, key_match]):
        print(f'[warn] Could not parse ssh-config for {m}, skipping')
        continue
    host = host_match.group(1)
    port = port_match.group(1)
    user = user_match.group(1)
    key  = key_match.group(1).strip().strip('"')
    lines.append(
        f"{m} ansible_host={host} ansible_port={port} "
        f"ansible_user={user} ansible_ssh_private_key_file={key}"
    )

# Windows group (WinRM)
win_hosts = [m for m in machines if m.startswith('ar-win')]
linux_hosts = [m for m in machines if not m.startswith('ar-win')]

if win_hosts:
    lines.append('\n[windows]')
    lines.extend(win_hosts)
    lines.append('[windows:vars]')
    lines.append('ansible_connection=winrm')
    lines.append('ansible_winrm_transport=basic')
    lines.append('ansible_port=5985')
    lines.append('ansible_winrm_scheme=http')

if linux_hosts:
    lines.append('\n[linux]')
    lines.extend(linux_hosts)

inv = '\n'.join(lines) + '\n'
out = pathlib.Path(__file__).resolve().parents[1] / 'inventory.ini'
out.write_text(inv, encoding='utf-8')
print(f'[ok] Inventory written to {out}')
print(inv)
