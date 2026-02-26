# Attack Range - Hyper-V Local Deployment

This page describes how to deploy Attack Range locally using **Hyper-V** on Windows,
replacing the cloud backend (AWS/Azure/GCP) with a fully local environment.
All features (webapp, API, WireGuard VPN, Atomic Red Team simulations) work identically.

## Architecture

```
Windows Host (Hyper-V)
  |
  +-- Default Switch (external, internet access)
  |     |
  |     +-- ar-router VM (Ubuntu, WireGuard server)
  |           eth0 -> Default Switch
  |           eth1 -> AttackRange-<id> Switch
  |
  +-- AttackRange-<id> Switch (internal NAT, 10.0.2.0/24)
        |
        +-- ar-splunk VM         (10.0.2.11)
        +-- ar-win10-victim VM   (10.0.2.12)
        +-- ar-kali VM           (10.0.2.13)
```

## Prerequisites

| Requirement | Version |
|---|---|
| Windows 10/11 Pro or Windows Server | with Hyper-V role enabled |
| Terraform | >= 1.5.0 |
| Packer | >= 1.9.0 |
| Python | >= 3.9 |
| Ansible | >= 2.15 (WSL or native) |
| Windows ADK (oscdimg) | Optional, fallback to WSL mkisofs |

## Step 1 - Build base images with Packer

```powershell
# Ubuntu 22.04 (used for Splunk, router, Kali base)
packer build packer/hyperv/ubuntu-22.04.pkr.hcl

# Windows Server 2022 (used for Windows victim VMs)
# Edit iso_url in the template first to point to your ISO
packer build packer/hyperv/windows-server-2022.pkr.hcl
```

## Step 2 - Configure

Edit `config/attack_range_hyperv.yml` to match your environment:
- Set `hyperv_host.host` to the IP of your Hyper-V host
- Set `hyperv_host.username` / `password` (WinRM credentials)
- Set all `vhdx_path` values to the paths output by Packer
- Set `router.router_ip` to the IP your WireGuard clients will connect to

## Step 3 - Deploy

```bash
python attack_range.py build --config config/attack_range_hyperv.yml
```

## Step 4 - Connect to VPN

Import the generated WireGuard config from `wireguard_config/` into your WireGuard client.
After connecting, the lab VMs are reachable at `10.0.2.11`, `10.0.2.12`, etc.

## Step 5 - Run simulations

```bash
python attack_range.py simulate --config config/attack_range_hyperv.yml \
  --target win10-victim --technique T1003.001
```

## Destroy

```bash
python attack_range.py destroy --config config/attack_range_hyperv.yml
```

This removes all Hyper-V VMs, the internal switch, the Windows NAT rule,
and the local `.tfstate` file.

## Key differences from cloud providers

| | AWS / Azure / GCP | Hyper-V |
|---|---|---|
| Terraform backend | S3 / Blob / GCS | Local `.tfstate` file |
| VM images | AMI / Marketplace | `.vhdx` built with Packer |
| SSH key upload | Cloud key-pair API | cloud-init injection |
| NAT / routing | Cloud NAT gateway | Windows `New-NetNat` |
| Router IP | Public cloud EIP | Hyper-V host LAN IP |
| Internet access | VPC Internet Gateway | Host NAT via Default Switch |
