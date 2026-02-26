"""Hyper-V local builder for Splunk Attack Range."""
from __future__ import annotations
import os
import subprocess
import json
import shutil
import tempfile
import pathlib
import yaml

BASE_DIR = pathlib.Path(__file__).resolve().parents[3]


class HypervBuilder:
    """Build an Attack Range on local Hyper-V using Terraform + Vagrant + Ansible."""

    def __init__(self, config: dict):
        self.config      = config
        self.general     = config['general']
        self.hyperv_cfg  = config.get('hyperv', {})
        self.servers     = config.get('attack_range', [])
        self.tf_dir      = BASE_DIR / 'terraform' / 'hyperv'
        self.vagrant_dir = BASE_DIR / 'vagrant'
        self.ansible_dir = BASE_DIR / 'ansible'
        self.password    = self.general['attack_range_password']
        self.ar_id       = self.general.get('attack_range_id', 'ar')

    # ------------------------------------------------------------------
    def build(self):
        print("[AR] === Hyper-V Attack Range Build ===")
        self._install_ansible_roles()
        self._terraform_apply()
        self._generate_inventory()
        self._ansible_provision()
        self._print_access_info()

    # ------------------------------------------------------------------
    def _install_ansible_roles(self):
        req = self.ansible_dir / 'requirements.yml'
        if not req.exists():
            return
        print("[AR] Installing Ansible Galaxy roles...")
        self._run(['ansible-galaxy', 'role', 'install', '-r', str(req)], cwd=self.ansible_dir)

    # ------------------------------------------------------------------
    def _terraform_apply(self):
        print("[AR] Running Terraform (Hyper-V provider)...")
        tfvars = self._build_tfvars()
        tfvars_path = self.tf_dir / 'terraform.tfvars.json'
        with open(tfvars_path, 'w') as f:
            json.dump(tfvars, f, indent=2)

        self._run(['terraform', 'init', '-upgrade'], cwd=self.tf_dir)
        self._run(['terraform', 'apply', '-auto-approve',
                   '-var-file', str(tfvars_path)], cwd=self.tf_dir)

    def _build_tfvars(self) -> dict:
        return {
            'general': {
                'attack_range_password': self.password,
                'attack_range_name':     self.general.get('attack_range_name', 'ar'),
                'attack_range_id':       self.ar_id,
                'cloud_provider':        'hyperv',
                'description':           self.general.get('description', ''),
            },
            'hyperv': {
                'switch_wan':      self.hyperv_cfg.get('switch_wan',  'CR-WAN'),
                'switch_mgmt':     self.hyperv_cfg.get('switch_mgmt', 'CR-MGMT'),
                'switch_ips1':     self.hyperv_cfg.get('switch_ips1', 'CR-IPS1'),
                'switch_ips2':     self.hyperv_cfg.get('switch_ips2', 'CR-IPS2'),
                'nat_name':        self.hyperv_cfg.get('nat_name',    'AR-NAT'),
                'host_wan_ip':     self.hyperv_cfg.get('host_wan_ip', '10.10.10.1'),
                'host_mgmt_ip':    self.hyperv_cfg.get('host_mgmt_ip', '172.16.100.2'),
                'subnet_mgmt':     self.hyperv_cfg.get('subnet_mgmt',    '172.16.100.0/24'),
                'subnet_targets':  self.hyperv_cfg.get('subnet_targets', '172.16.101.0/24'),
            },
            'attack_range': self.servers,
        }

    # ------------------------------------------------------------------
    def _generate_inventory(self):
        print("[AR] Generating Ansible inventory from Vagrant...")
        tool = self.ansible_dir / 'tools' / 'vagrant_inventory.py'
        self._run(['python', str(tool), str(self.vagrant_dir)], cwd=self.ansible_dir)

    # ------------------------------------------------------------------
    def _ansible_provision(self):
        print("[AR] Running Ansible provisioning...")
        site_yml = self._generate_site_yml()
        site_path = self.ansible_dir / 'site_generated.yml'
        with open(site_path, 'w') as f:
            yaml.dump(site_yml, f, default_flow_style=False, allow_unicode=True)

        self._run([
            'ansible-playbook', '-i', str(self.ansible_dir / 'inventory.ini'),
            str(site_path)
        ], cwd=self.ansible_dir)

    def _generate_site_yml(self) -> list:
        """Build site.yml plays from template roles."""
        linux_plays  = []
        windows_plays = []
        for s in self.servers:
            if not s.get('roles'):
                continue
            hosts = f"ar-{s['name']}"
            for role_def in s['roles']:
                play = {
                    'name': f"Provision {s['name']} - {role_def['role']}",
                    'hosts': hosts,
                    'gather_facts': True,
                    'become': True,
                    'roles': [{
                        'role': role_def['role'],
                        'vars': role_def.get('vars', {})
                    }]
                }
                if s.get('os') == 'windows':
                    play['become'] = False
                    play['vars'] = {
                        'ansible_connection': 'winrm',
                        'ansible_winrm_transport': 'basic',
                        'ansible_port': 5985,
                        'ansible_winrm_scheme': 'http',
                    }
                    windows_plays.append(play)
                else:
                    linux_plays.append(play)
        return linux_plays + windows_plays

    # ------------------------------------------------------------------
    def _print_access_info(self):
        print("\n" + "=" * 60)
        print("[AR] Attack Range Ready!")
        print("=" * 60)
        for s in self.servers:
            octet = s.get('ip_last_octet', '?')
            prefix = '172.16.100' if int(octet) <= 19 else '172.16.101'
            ip = f"{prefix}.{octet}"
            name = s['name']
            if name == 'splunk':
                print(f"  Splunk Web   : http://{ip}:8000  (admin / {self.password})")
                print(f"  Guacamole    : http://{ip}:8080  (guacadmin / {self.password})")
            elif s.get('os') == 'windows':
                print(f"  RDP {name:12}: {ip}:3389")
            else:
                print(f"  SSH {name:12}: ssh vagrant@{ip}")
        print("=" * 60 + "\n")

    # ------------------------------------------------------------------
    @staticmethod
    def _run(cmd: list, cwd=None):
        result = subprocess.run(cmd, cwd=cwd)
        if result.returncode != 0:
            raise RuntimeError(f"Command failed (exit {result.returncode}): {' '.join(str(c) for c in cmd)}")
