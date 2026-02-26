"""
Hyper-V local provider for Attack Range.

This module implements the BaseCloudProvider interface for local Hyper-V deployments.
It replaces cloud-specific concepts (AMI, S3 backend, cloud SSH key import) with
local equivalents: .vhdx images built with Packer, local Terraform state file,
and SSH keys managed purely on disk.
"""

import os
import re
import logging
from typing import Optional
from .base_provider import BaseCloudProvider, BackendParams


class HyperVProvider(BaseCloudProvider):
    """
    Provider for local Hyper-V deployment.

    Key differences from cloud providers:
    - No region concept: always returns 'local'
    - Backend is a local .tfstate file, not S3/GCS/Azure Storage
    - SSH keys are managed on disk only; no cloud key-pair API is called
    - No NAT gateway or VPC: Hyper-V internal switch + Windows NAT
    """

    def __init__(self, config: dict, logger: logging.Logger):
        super().__init__(config, logger)
        self.hyperv_config = config.get("hyperv_host", {})

    # ------------------------------------------------------------------
    # Region
    # ------------------------------------------------------------------

    def get_region(self, required: bool = True) -> Optional[str]:
        """
        Hyper-V has no region concept.
        Returns the fixed string 'local' so that callers always get a non-None value.
        """
        return "local"

    # ------------------------------------------------------------------
    # Backend (Terraform state)
    # ------------------------------------------------------------------

    def check_backend_exists(self, backend_name: str) -> bool:
        """
        For Hyper-V the backend is a local file.
        Returns True if the .tfstate file already exists on disk.
        """
        state_path = os.path.join("config", f"{backend_name}.tfstate")
        exists = os.path.exists(state_path)
        self.logger.debug(f"[hyperv] check_backend_exists: {state_path} -> {exists}")
        return exists

    def create_backend(self, backend_name: str, region: str) -> None:
        """
        No remote resource to create for a local backend.
        Ensures the config/ directory exists so Terraform can write the state file.
        """
        os.makedirs("config", exist_ok=True)
        self.logger.info(
            f"[hyperv] Local backend ready. State will be stored in: config/{backend_name}.tfstate"
        )

    def delete_backend(self, backend_name: str, region: str) -> None:
        """
        Removes the local .tfstate file when the range is destroyed.
        """
        state_path = os.path.join("config", f"{backend_name}.tfstate")
        backup_path = state_path + ".backup"
        for path in [state_path, backup_path]:
            if os.path.exists(path):
                os.remove(path)
                self.logger.info(f"[hyperv] Removed local state file: {path}")

    # ------------------------------------------------------------------
    # Naming
    # ------------------------------------------------------------------

    def sanitize_name(self, name: str) -> str:
        """
        Sanitize a name to safe characters for file paths and Hyper-V VM names.
        Replaces any character that is not alphanumeric or a hyphen with a hyphen.
        """
        return re.sub(r"[^a-zA-Z0-9\-]", "-", name).lower()

    # ------------------------------------------------------------------
    # SSH Keys
    # ------------------------------------------------------------------

    def import_ssh_key(self, key_name: str, public_key_content: str, region: str) -> None:
        """
        In Hyper-V there is no cloud key-pair store.
        The SSH public key is injected into VM images either:
          - via Packer provisioner at build time, OR
          - via cloud-init user-data on first boot.
        This method just logs the action; the actual injection is handled by Terraform
        through the cloud-init configuration rendered from templates.
        """
        self.logger.info(
            f"[hyperv] SSH key '{key_name}' is managed locally. "
            "It will be injected into VMs via cloud-init at first boot."
        )

    def delete_ssh_key(self, key_name: str, region: str) -> None:
        """
        No remote resource to remove. The local key files are handled by SSHManager.
        """
        self.logger.info(
            f"[hyperv] SSH key '{key_name}': no remote resource to remove (local only)."
        )

    # ------------------------------------------------------------------
    # Backend configuration file
    # ------------------------------------------------------------------

    def write_backend_config(self, backend_params: BackendParams, backend_file_path: str) -> None:
        """
        Writes a backend.tf file that configures Terraform to use a local state file.
        The path is relative to the terraform/hyperv/ working directory.
        """
        content = (
            "# Auto-generated backend configuration for Hyper-V (local) deployment.\n"
            "# Do not edit manually — regenerated on each 'attack_range build'.\n"
            "# Source: {config_source}\n\n"
            "terraform {{\n"
            "  backend \"local\" {{\n"
            "    path = \"../../config/{backend_name}.tfstate\"\n"
            "  }}\n"
            "}}\n"
        ).format(
            config_source=backend_params.config_source,
            backend_name=backend_params.backend_name,
        )

        os.makedirs(os.path.dirname(backend_file_path), exist_ok=True)
        with open(backend_file_path, "w", encoding="utf-8") as f:
            f.write(content)
        self.logger.info(f"[hyperv] Backend config written to: {backend_file_path}")

    def get_backend_params(self, attack_range_id: str, config_source: str = "template/config file") -> BackendParams:
        """
        Returns backend parameters for local Hyper-V deployment.
        Only backend_name and region are meaningful here; all cloud-specific
        fields (aws_bucket_name, gcp_bucket_name, etc.) are left as None.
        """
        return BackendParams(
            backend_name=self.sanitize_name(f"ar-{attack_range_id}"),
            region="local",
            attack_range_id=attack_range_id,
            config_source=config_source,
        )
