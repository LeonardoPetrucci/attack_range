# Splunk Attack Range - Hyper-V Local

Fork di [splunk/attack_range](https://github.com/splunk/attack_range) adattato per deployment
locale su **Microsoft Hyper-V** (Windows 10/11 Pro o Windows Server 2019/2022).

## Requisiti host

| Risorsa | Minimo | Consigliato |
|---------|--------|-------------|
| RAM | 20 GB liberi | 32 GB totali |
| CPU | 8 vCPU liberi | 16 vCPU totali |
| Disco | 200 GB SSD | 500 GB NVMe |
| OS | Windows 10/11 Pro | Windows 11 Pro / Server 2022 |
| Hyper-V | Abilitato | Abilitato + SLAT |

## Risorse VM per template

| Template | VMs | RAM totale | vCPU totali |
|----------|-----|-----------|-------------|
| `splunk_minimal_hyperv` | 1 Splunk | 8 GB | 4 |
| `splunk_windows_hyperv` | Splunk + Win | 12 GB | 6 |
| `splunk_ad_hyperv` | Splunk + DC + Win | 18 GB | 8 |
| `splunk_linux_hyperv` | Splunk + Linux | 12 GB | 6 |
| `splunk_windows_kali_hyperv` | Splunk + DC + Win + Kali | 22 GB | 10 |
| `splunk_zeek_windows_hyperv` | Splunk + Zeek + DC + Win | 24 GB | 10 |

## Setup rapido

### 1. Bootstrap host (una tantum)

```powershell
# In PowerShell come Amministratore
.\bootstrap\Bootstrap-AttackRange.ps1 -ExternalInterfaceAlias "Wi-Fi"
```

### 2. Clona il repo

```bash
git clone https://github.com/LeonardoPetrucci/attack_range
cd attack_range
git checkout hyperv-local
pip install -r requirements-hyperv.txt
```

### 3. Build del range

```bash
# Template AD completo (Splunk + DC + endpoint Windows)
python attack_range.py build -t splunk_ad_hyperv

# Template minimo (solo Splunk)
python attack_range.py build -t splunk_minimal_hyperv

# Template full purple team (Splunk + AD + Kali)
python attack_range.py build -t splunk_windows_kali_hyperv
```

### 4. Simulazione attacchi (Atomic Red Team)

```bash
python attack_range.py simulate -t win-dc --techniques T1003.001,T1059.003
```

### 5. Destroy

```bash
python attack_range.py destroy
```

## Rete

```
Internet
   |
[vSwitch CR-WAN]  10.10.10.0/24  <-- NetNAT (NAT verso internet)
   |
[ar-router]  172.16.100.1 (mgmt) + 172.16.101.1 (targets)
   |
   +-- [vSwitch CR-MGMT] 172.16.100.0/24
   |     +-- ar-splunk   172.16.100.10
   |
   +-- [vSwitch CR-IPS1] 172.16.101.0/24
         +-- ar-win-dc  172.16.101.11
         +-- ar-win     172.16.101.12
         +-- ar-kali    172.16.101.50
```

## Porte accessibili dall'host

| Servizio | IP | Porta |
|----------|----|-------|
| Splunk Web | 172.16.100.10 | 8000 |
| Guacamole | 172.16.100.10 | 8080 |
| Splunk HEC | 172.16.100.10 | 8088 |
| RDP win-dc | 172.16.101.11 | 3389 |
| RDP win | 172.16.101.12 | 3389 |
| SSH kali | 172.16.101.50 | 22 |

## Template custom

Puoi creare il tuo template in `templates/hyperv/`. Ogni VM nel template supporta:

```yaml
- name: <nome>           # nome univoco VM
  os: linux | windows   # tipo OS
  box: <vagrant-box>     # box Vagrant Hyper-V compatibile
  ip_last_octet: <N>     # IP: 172.16.100.N (<=19) o 172.16.101.N (>19)
  memory_mb: <MB>        # RAM (default 4096)
  cpus: <N>              # vCPU (default 2)
  zeek: true             # questa VM è il Zeek monitor
  zeek_monitor: true     # inviare traffico di questa VM a Zeek
  roles:                 # ruoli Ansible da applicare
    - role: <nome-ruolo>
      vars: { ... }
```

## Packer (immagini custom)

Se vuoi buildare le box Hyper-V invece di scaricarle da Vagrant Cloud:

```bash
cd packer/
# Ubuntu 22.04
packer build ubuntu-base.pkr.hcl
# Windows Server 2022 (richiede ISO da Microsoft Evaluation Center)
packer build windows-server-2022.pkr.hcl
```

Le box vengono salvate nella directory corrente e possono essere aggiunte a Vagrant:

```bash
vagrant box add ar-ubuntu-base ./hyperv_ubuntu-base.box --provider hyperv
vagrant box add ar-win-2022    ./hyperv_win-server-2022.box --provider hyperv
```
