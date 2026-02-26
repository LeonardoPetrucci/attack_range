"""AttackRangeController - patched for Hyper-V local provider."""
from __future__ import annotations
import os
import sys
import subprocess
import pathlib
import yaml

BASE_DIR = pathlib.Path(__file__).resolve().parents[1]


class AttackRangeController:
    """Unified controller. Routes to provider-specific builder/destroyer."""

    def __init__(self, config: dict, config_path: str = ''):
        self.config      = config
        self.config_path = config_path
        self.provider    = config.get('general', {}).get('cloud_provider', 'aws')

    # ------------------------------------------------------------------
    def build(self):
        if self.provider == 'hyperv':
            from attack_range.providers.hyperv.builder import HypervBuilder
            HypervBuilder(self.config).build()
        elif self.provider == 'aws':
            self._terraform_action('apply')
        elif self.provider in ('azure', 'gcp'):
            self._terraform_action('apply')
        else:
            raise ValueError(f"Unknown provider: {self.provider}")

    # ------------------------------------------------------------------
    def destroy(self):
        if self.provider == 'hyperv':
            from attack_range.providers.hyperv.destroyer import HypervDestroyer
            HypervDestroyer(self.config).destroy()
        elif self.provider in ('aws', 'azure', 'gcp'):
            self._terraform_action('destroy')
        else:
            raise ValueError(f"Unknown provider: {self.provider}")

    # ------------------------------------------------------------------
    def simulate(self, target: str, techniques: list[str]):
        """Run Atomic Red Team via Ansible on target."""
        print(f"[AR] simulate: target={target} techniques={techniques}")
        ansible_dir = BASE_DIR / 'ansible'
        playbook    = BASE_DIR / 'terraform' / 'ansible' / 'simulate_atomic_red_team.yml'
        if not playbook.exists():
            playbook = ansible_dir / 'simulate_atomic_red_team.yml'
        if not playbook.exists():
            raise FileNotFoundError(f"simulate playbook not found at {playbook}")

        inv = ansible_dir / 'inventory.ini'
        if not inv.exists():
            raise FileNotFoundError(f"inventory.ini not found. Run build first.")

        tech_str = ','.join(techniques)
        cmd = [
            'ansible-playbook', '-i', str(inv),
            str(playbook),
            '--limit', f'ar-{target}',
            '-e', f'techniques={tech_str}',
            '-e', f'art_run_tests=true',
        ]
        result = subprocess.run(cmd, cwd=ansible_dir)
        if result.returncode != 0:
            raise RuntimeError(f"Simulation failed for target {target}")

    # ------------------------------------------------------------------
    def share(self, name: str) -> str:
        """Generate WireGuard config for sharing (only for cloud providers)."""
        if self.provider == 'hyperv':
            raise ValueError("share() is not supported for the hyperv provider. Use VPN or direct network access.")
        raise NotImplementedError("share() for cloud providers not implemented in this fork.")

    # ------------------------------------------------------------------
    def _terraform_action(self, action: str):
        tf_dir = BASE_DIR / 'terraform' / self.provider
        if not tf_dir.exists():
            raise FileNotFoundError(f"Terraform dir not found: {tf_dir}")
        cmd_init    = ['terraform', 'init', '-upgrade']
        cmd_action  = ['terraform', action, '-auto-approve']
        subprocess.run(cmd_init,   cwd=tf_dir, check=True)
        subprocess.run(cmd_action, cwd=tf_dir, check=True)
