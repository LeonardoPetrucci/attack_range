"""Utility functions for Attack Range - patched for hyperv provider."""
from __future__ import annotations
import os
import uuid
import yaml
import pathlib


def prepare_config_from_template(
    template_name: str,
    templates_dir: str,
    config_dir: str,
    generate_id: bool = True,
) -> tuple[dict, str, str]:
    """
    Load a template YAML, inject metadata (attack_range_id),
    save to config/ and return (config_dict, config_path, attack_range_id).
    """
    template_path = resolve_template_path(template_name, templates_dir)
    with open(template_path, 'r', encoding='utf-8') as f:
        config = yaml.safe_load(f)

    attack_range_id = str(uuid.uuid4())[:8] if generate_id else ''
    if 'general' not in config:
        config['general'] = {}
    config['general']['attack_range_id'] = attack_range_id

    os.makedirs(config_dir, exist_ok=True)
    base   = pathlib.Path(template_path).stem
    cfgpath = os.path.join(config_dir, f"{base}_{attack_range_id}.yml")
    with open(cfgpath, 'w', encoding='utf-8') as f:
        yaml.dump(config, f, default_flow_style=False, allow_unicode=True)

    return config, cfgpath, attack_range_id


def resolve_template_path(template_name: str, templates_dir: str) -> str:
    """
    Resolve template name to a file path.
    Supports:
      - full path                         e.g. /abs/path/to/tpl.yml
      - relative path                     e.g. hyperv/splunk_ad_hyperv.yml
      - name without extension/subdir     e.g. splunk_ad_hyperv
    Searches: hyperv/, aws/, azure/, gcp/, root of templates_dir.
    """
    # Already an absolute path
    if os.path.isabs(template_name) and os.path.isfile(template_name):
        return template_name

    # Add .yml extension if missing
    if not template_name.endswith(('.yml', '.yaml')):
        template_name += '.yml'

    # Direct relative path
    candidate = os.path.join(templates_dir, template_name)
    if os.path.isfile(candidate):
        return candidate

    # Search in provider subdirs
    for provider in ['hyperv', 'aws', 'azure', 'gcp']:
        candidate = os.path.join(templates_dir, provider, template_name)
        if os.path.isfile(candidate):
            return candidate
        # Also try without provider prefix in filename
        stem = pathlib.Path(template_name).stem
        candidate2 = os.path.join(templates_dir, provider,
                                  f"{stem}_{provider}.yml")
        if os.path.isfile(candidate2):
            return candidate2

    raise FileNotFoundError(
        f"Template '{template_name}' not found in {templates_dir}. "
        f"Available providers: hyperv, aws, azure, gcp."
    )
