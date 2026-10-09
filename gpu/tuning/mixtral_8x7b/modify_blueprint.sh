#!/bin/bash
set -euo pipefail

YAML_PATH="${1:-}"
echo "Modifying blueprint at: ${YAML_PATH}"

# 1. Update install_managed_lustre to true in /var/tmp/slurm_vars.json
sed -i 's/"install_managed_lustre": false/"install_managed_lustre": true/' "$YAML_PATH"

# 2. Uncomment per_unit_storage_throughput: 500
sed -i 's/# per_unit_storage_throughput: 500/per_unit_storage_throughput: 500/' "$YAML_PATH"

# 3. Uncomment lustre_size_gib: 36000
sed -i 's/# lustre_size_gib: 36000/lustre_size_gib: 36000/' "$YAML_PATH"

# 4. Uncomment lustre_instance_id: lustre-instance and add lustre_zone
sed -i 's/# lustre_instance_id: lustre-instance/lustre_instance_id: lustre-instance\n  lustre_zone:/' "$YAML_PATH"

# 5. Comment out unused filestore_ip_range in vars
sed -i 's/^  filestore_ip_range:/  # filestore_ip_range:/' "$YAML_PATH"

# 6. Remove the 'filestore' module block and enable the 'managed-lustre' and 'private-service-access' modules
python3 -c "
import re
with open('$YAML_PATH', 'r') as f:
    text = f.read()

# Remove Filestore homefs module
text = re.sub(r'  - id: homefs\n    source: modules/file-system/filestore[\s\S]*?outputs:\n\s*- network_storage\n', '', text)

# Uncomment private_service_access and managed-lustre modules
pattern = r'(?:#\s*)?- id: private_service_access[\s\S]*?#\s*- network_storage'
def uncomment(m):
    return '\n'.join([re.sub(r'^(\s*)#\s?', r'\1', line) for line in m.group(0).splitlines()])

text = re.sub(pattern, uncomment, text)

# Set zone: \$(vars.lustre_zone) in the managed-lustre module settings
text = re.sub(
    r'(source: modules/file-system/managed-lustre[\s\S]*?settings:\n)',
    r'\1      zone: \$(vars.lustre_zone)\n',
    text,
)

# Workaround: set network_name to default-nemo-rl for a4high-slurm-net-0 to use existing Managed Lustre quota in dx-supercomputer-testing project
text = text.replace(
    'network_name: \$(vars.base_network_name)-net-0',
    'network_name: default-nemo-rl',
)

with open('$YAML_PATH', 'w') as f:
    f.write(text)
"

echo "Updated $YAML_PATH successfully."