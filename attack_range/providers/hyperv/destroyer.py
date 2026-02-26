"""Hyper-V local destroyer for Splunk Attack Range."""
from __future__ import annotations
import subprocess
import pathlib
import json

BASE_DIR = pathlib.Path(__file__).resolve().parents[3]


class HypervDestroyer:
    """Destroy an Attack Range on local Hyper-V."""

    def __init__(self, config: dict):
        self.config     = config
        self.general    = config['general']
        self.servers    = config.get('attack_range', [])
        self.tf_dir     = BASE_DIR / 'terraform' / 'hyperv'
        self.vagrant_dir = BASE_DIR / 'vagrant'

    def destroy(self):
        print("[AR] === Hyper-V Attack Range Destroy ===")
        self._terraform_destroy()
        print("[AR] Destroy complete.")

    def _terraform_destroy(self):
        print("[AR] Running Terraform destroy...")
        tfvars_path = self.tf_dir / 'terraform.tfvars.json'
        if not tfvars_path.exists():
            # Rebuild tfvars from config
            hyperv_cfg = self.config.get('hyperv', {})
            tfvars = {
                'general': {
                    'attack_range_password': self.general['attack_range_password'],
                    'attack_range_name':     self.general.get('attack_range_name', 'ar'),
                    'attack_range_id':       self.general.get('attack_range_id', 'ar'),
                    'cloud_provider':        'hyperv',
                    'description':           '',
                },
                'hyperv': {
                    'switch_wan':     hyperv_cfg.get('switch_wan',  'CR-WAN'),
                    'switch_mgmt':    hyperv_cfg.get('switch_mgmt', 'CR-MGMT'),
                    'switch_ips1':    hyperv_cfg.get('switch_ips1', 'CR-IPS1'),
                    'switch_ips2':    hyperv_cfg.get('switch_ips2', 'CR-IPS2'),
                    'nat_name':       hyperv_cfg.get('nat_name',    'AR-NAT'),
                    'host_wan_ip':    hyperv_cfg.get('host_wan_ip', '10.10.10.1'),
                    'host_mgmt_ip':   hyperv_cfg.get('host_mgmt_ip', '172.16.100.2'),
                    'subnet_mgmt':    hyperv_cfg.get('subnet_mgmt', '172.16.100.0/24'),
                    'subnet_targets': hyperv_cfg.get('subnet_targets', '172.16.101.0/24'),
                },
                'attack_range': self.servers,
            }
            with open(tfvars_path, 'w') as f:
                json.dump(tfvars, f, indent=2)

        self._run(['terraform', 'init'], cwd=self.tf_dir)
        self._run(['terraform', 'destroy', '-auto-approve',
                   '-var-file', str(tfvars_path)], cwd=self.tf_dir)

    @staticmethod
    def _run(cmd: list, cwd=None):
        result = subprocess.run(cmd, cwd=cwd)
        if result.returncode != 0:
            raise RuntimeError(f"Command failed (exit {result.returncode}): {' '.join(str(c) for c in cmd)}")
