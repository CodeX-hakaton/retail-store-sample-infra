#!/usr/bin/env python3

import argparse
import json
import shlex
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


@dataclass(frozen=True)
class AuroraSpec:
    name: str
    engine: str
    instance_class: str
    security_group_output: str

    @property
    def cluster_identifier(self) -> str:
        return f"{ARGS.environment_name}-{self.name}"

    @property
    def instance_identifier(self) -> str:
        return f"{self.cluster_identifier}-one"

    @property
    def subnet_group_name(self) -> str:
        return self.cluster_identifier

    @property
    def recovery_suffix(self) -> str:
        return f":cluster:{self.cluster_identifier}"

    @property
    def subnet_group_address(self) -> str:
        return f"module.dependencies.module.{self.name}_rds.aws_db_subnet_group.this[0]"

    @property
    def cluster_address(self) -> str:
        return f"module.dependencies.module.{self.name}_rds.aws_rds_cluster.this[0]"

    @property
    def instance_address(self) -> str:
        return f'module.dependencies.module.{self.name}_rds.aws_rds_cluster_instance.this["one"]'


@dataclass(frozen=True)
class DynamoSpec:
    name: str

    @property
    def table_name(self) -> str:
        return f"{ARGS.environment_name}-{self.name}"

    @property
    def recovery_suffix(self) -> str:
        return f":table/{self.table_name}"

    @property
    def table_address(self) -> str:
        return "module.dependencies.module.dynamodb_carts.aws_dynamodb_table.this[0]"


def run(cmd, *, capture_output=True, cwd=None):
    printable = " ".join(shlex.quote(part) for part in cmd)
    print(f"+ {printable}", file=sys.stderr)
    return subprocess.run(
        cmd,
        cwd=cwd,
        check=True,
        text=True,
        capture_output=capture_output,
    )


def aws_json(*args):
    result = run([ARGS.aws_bin, *args, "--output", "json"], cwd=ARGS.tf_dir)
    return json.loads(result.stdout)


def terraform_json(*args):
    result = run([ARGS.terraform_bin, f"-chdir={ARGS.tf_dir}", *args], cwd=ARGS.tf_dir)
    return json.loads(result.stdout)


def set_metadata_value(metadata, aliases, value):
    lowered = {alias.lower() for alias in aliases}
    for key in list(metadata.keys()):
        if key.lower() in lowered:
            metadata[key] = value
            return
    metadata[aliases[0]] = value


def delete_metadata_keys(metadata, aliases):
    lowered = {alias.lower() for alias in aliases}
    for key in list(metadata.keys()):
        if key.lower() in lowered:
            metadata.pop(key, None)


def load_terraform_outputs():
    outputs = terraform_json("output", "-json")
    required = [
        "private_subnet_ids",
        "catalog_security_group_id",
        "orders_security_group_id",
    ]
    missing = [name for name in required if name not in outputs]
    if missing:
        names = ", ".join(sorted(missing))
        raise RuntimeError(
            "Missing Terraform outputs: "
            f"{names}. Run `terraform apply -target=module.vpc -target=module.component_security_groups` first."
        )
    return {name: outputs[name]["value"] for name in outputs}


def list_recovery_points():
    payload = aws_json(
        "backup",
        "list-recovery-points-by-backup-vault",
        "--region",
        ARGS.region,
        "--backup-vault-name",
        ARGS.backup_vault_name,
        "--max-results",
        "1000",
    )
    return payload.get("RecoveryPoints", [])


def latest_recovery_point(recovery_points, suffix, explicit_arn=None):
    if explicit_arn:
        for point in recovery_points:
            if point.get("RecoveryPointArn") == explicit_arn:
                return point
        raise RuntimeError(f"Recovery point {explicit_arn} was not found in vault {ARGS.backup_vault_name}.")

    matches = [
        point for point in recovery_points
        if point.get("ResourceArn", "").endswith(suffix)
    ]
    if not matches:
        raise RuntimeError(f"No recovery point found in {ARGS.backup_vault_name} matching {suffix}.")

    matches.sort(key=lambda point: point.get("CreationDate", ""))
    return matches[-1]


def recovery_metadata(point):
    payload = aws_json(
        "backup",
        "get-recovery-point-restore-metadata",
        "--region",
        ARGS.region,
        "--backup-vault-name",
        ARGS.backup_vault_name,
        "--recovery-point-arn",
        point["RecoveryPointArn"],
    )
    return payload.get("RestoreMetadata", {})


def ensure_db_subnet_group(name, subnet_ids):
    try:
        aws_json(
            "rds",
            "describe-db-subnet-groups",
            "--region",
            ARGS.region,
            "--db-subnet-group-name",
            name,
        )
        return
    except subprocess.CalledProcessError:
        pass

    run(
        [
            ARGS.aws_bin,
            "rds",
            "create-db-subnet-group",
            "--region",
            ARGS.region,
            "--db-subnet-group-name",
            name,
            "--db-subnet-group-description",
            f"DR restore subnet group for {name}",
            "--subnet-ids",
            *subnet_ids,
        ],
        cwd=ARGS.tf_dir,
        capture_output=False,
    )


def wait_for_restore(job_id):
    while True:
        payload = aws_json(
            "backup",
            "describe-restore-job",
            "--region",
            ARGS.region,
            "--restore-job-id",
            job_id,
        )
        status = payload.get("Status")
        if status == "COMPLETED":
            return payload
        if status in {"ABORTED", "FAILED", "EXPIRED"}:
            message = payload.get("StatusMessage", "unknown restore failure")
            raise RuntimeError(f"Restore job {job_id} failed with status {status}: {message}")
        time.sleep(15)


def start_restore_job(resource_type, recovery_point_arn, metadata):
    payload = aws_json(
        "backup",
        "start-restore-job",
        "--region",
        ARGS.region,
        "--recovery-point-arn",
        recovery_point_arn,
        "--resource-type",
        resource_type,
        "--iam-role-arn",
        ARGS.iam_role_arn,
        "--copy-source-tags-to-restored-resource",
        "--metadata",
        json.dumps(metadata, separators=(",", ":")),
    )
    return payload["RestoreJobId"]


def ensure_aurora_instance(spec):
    try:
        aws_json(
            "rds",
            "describe-db-instances",
            "--region",
            ARGS.region,
            "--db-instance-identifier",
            spec.instance_identifier,
        )
        return
    except subprocess.CalledProcessError:
        pass

    run(
        [
            ARGS.aws_bin,
            "rds",
            "create-db-instance",
            "--region",
            ARGS.region,
            "--db-instance-identifier",
            spec.instance_identifier,
            "--db-cluster-identifier",
            spec.cluster_identifier,
            "--engine",
            spec.engine,
            "--db-instance-class",
            spec.instance_class,
            "--no-publicly-accessible",
        ],
        cwd=ARGS.tf_dir,
        capture_output=False,
    )
    run(
        [
            ARGS.aws_bin,
            "rds",
            "wait",
            "db-instance-available",
            "--region",
            ARGS.region,
            "--db-instance-identifier",
            spec.instance_identifier,
        ],
        cwd=ARGS.tf_dir,
        capture_output=False,
    )


def restore_aurora(spec, point, outputs):
    ensure_db_subnet_group(spec.subnet_group_name, outputs["private_subnet_ids"])
    metadata = recovery_metadata(point)
    set_metadata_value(metadata, ["dbClusterIdentifier", "DBClusterIdentifier"], spec.cluster_identifier)
    set_metadata_value(metadata, ["dbSubnetGroupName", "DBSubnetGroupName"], spec.subnet_group_name)
    set_metadata_value(
        metadata,
        ["vpcSecurityGroupIds", "VpcSecurityGroupIds"],
        json.dumps([outputs[spec.security_group_output]]),
    )
    delete_metadata_keys(metadata, ["dbClusterParameterGroupName", "DBClusterParameterGroupName"])
    delete_metadata_keys(metadata, ["dbParameterGroupName", "DBParameterGroupName"])

    restore_job_id = start_restore_job(point["ResourceType"], point["RecoveryPointArn"], metadata)
    print(f"Started {spec.name} restore job {restore_job_id}", file=sys.stderr)

    if ARGS.wait:
        wait_for_restore(restore_job_id)
        run(
            [
                ARGS.aws_bin,
                "rds",
                "wait",
                "db-cluster-available",
                "--region",
                ARGS.region,
                "--db-cluster-identifier",
                spec.cluster_identifier,
            ],
            cwd=ARGS.tf_dir,
            capture_output=False,
        )
        ensure_aurora_instance(spec)

    return {
        "restore_job_id": restore_job_id,
        "cluster_identifier": spec.cluster_identifier,
        "instance_identifier": spec.instance_identifier,
        "subnet_group_name": spec.subnet_group_name,
        "recovery_point_arn": point["RecoveryPointArn"],
    }


def restore_dynamodb(spec, point):
    metadata = recovery_metadata(point)
    set_metadata_value(metadata, ["targetTableName", "TargetTableName"], spec.table_name)

    restore_job_id = start_restore_job(point["ResourceType"], point["RecoveryPointArn"], metadata)
    print(f"Started {spec.name} restore job {restore_job_id}", file=sys.stderr)

    if ARGS.wait:
        wait_for_restore(restore_job_id)
        run(
            [
                ARGS.aws_bin,
                "dynamodb",
                "wait",
                "table-exists",
                "--region",
                ARGS.region,
                "--table-name",
                spec.table_name,
            ],
            cwd=ARGS.tf_dir,
            capture_output=False,
        )

    return {
        "restore_job_id": restore_job_id,
        "table_name": spec.table_name,
        "recovery_point_arn": point["RecoveryPointArn"],
    }


def write_import_script(output_dir, catalog, orders, carts):
    lines = [
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "",
        f"cd {shlex.quote(str(ARGS.repo_root))}",
        "",
    ]

    removals = [
        "module.dependencies.module.catalog_rds.aws_db_subnet_group.this[0]",
        "module.dependencies.module.catalog_rds.aws_rds_cluster.this[0]",
        'module.dependencies.module.catalog_rds.aws_rds_cluster_instance.this["one"]',
        "module.dependencies.module.orders_rds.aws_db_subnet_group.this[0]",
        "module.dependencies.module.orders_rds.aws_rds_cluster.this[0]",
        'module.dependencies.module.orders_rds.aws_rds_cluster_instance.this["one"]',
        "module.dependencies.module.dynamodb_carts.aws_dynamodb_table.this[0]",
    ]

    for address in removals:
        lines.append(
            f"{shlex.quote(ARGS.terraform_bin)} -chdir={shlex.quote(str(ARGS.tf_dir))} state rm {shlex.quote(address)} || true"
        )

    lines.extend(
        [
            f"{shlex.quote(ARGS.terraform_bin)} -chdir={shlex.quote(str(ARGS.tf_dir))} import {shlex.quote(AURORA_SPECS[0].subnet_group_address)} {shlex.quote(catalog['subnet_group_name'])}",
            f"{shlex.quote(ARGS.terraform_bin)} -chdir={shlex.quote(str(ARGS.tf_dir))} import {shlex.quote(AURORA_SPECS[0].cluster_address)} {shlex.quote(catalog['cluster_identifier'])}",
            f"{shlex.quote(ARGS.terraform_bin)} -chdir={shlex.quote(str(ARGS.tf_dir))} import {shlex.quote(AURORA_SPECS[0].instance_address)} {shlex.quote(catalog['instance_identifier'])}",
            f"{shlex.quote(ARGS.terraform_bin)} -chdir={shlex.quote(str(ARGS.tf_dir))} import {shlex.quote(AURORA_SPECS[1].subnet_group_address)} {shlex.quote(orders['subnet_group_name'])}",
            f"{shlex.quote(ARGS.terraform_bin)} -chdir={shlex.quote(str(ARGS.tf_dir))} import {shlex.quote(AURORA_SPECS[1].cluster_address)} {shlex.quote(orders['cluster_identifier'])}",
            f"{shlex.quote(ARGS.terraform_bin)} -chdir={shlex.quote(str(ARGS.tf_dir))} import {shlex.quote(AURORA_SPECS[1].instance_address)} {shlex.quote(orders['instance_identifier'])}",
            f"{shlex.quote(ARGS.terraform_bin)} -chdir={shlex.quote(str(ARGS.tf_dir))} import {shlex.quote(DYNAMO_SPEC.table_address)} {shlex.quote(carts['table_name'])}",
            "",
        ]
    )

    import_script = output_dir / "terraform-imports.sh"
    import_script.write_text("\n".join(lines), encoding="ascii")
    import_script.chmod(0o755)
    return import_script


def parse_args():
    parser = argparse.ArgumentParser(
        description="Restore the latest DR backups and generate Terraform import commands."
    )
    parser.add_argument("--environment-name", required=True, help="Terraform environment_name, for example codex-production.")
    parser.add_argument("--region", required=True, help="DR AWS region, for example eu-central-1.")
    parser.add_argument("--tf-dir", default="terraform", help="Path to the Terraform root.")
    parser.add_argument("--backup-vault-name", default=None, help="Backup vault name in the DR region. Defaults to <environment-name>-<region>.")
    parser.add_argument("--iam-role-arn", default=None, help="IAM role ARN used by AWS Backup restores. Defaults to arn:aws:iam::<account>:role/<environment-name>-aws-backup.")
    parser.add_argument("--catalog-recovery-point-arn", default=None, help="Override the catalog Aurora recovery point ARN.")
    parser.add_argument("--orders-recovery-point-arn", default=None, help="Override the orders Aurora recovery point ARN.")
    parser.add_argument("--carts-recovery-point-arn", default=None, help="Override the carts DynamoDB recovery point ARN.")
    parser.add_argument("--wait", action="store_true", help="Wait for restore jobs and Aurora instance creation to finish.")
    parser.add_argument("--run-imports", action="store_true", help="Execute the generated Terraform import script after writing it.")
    parser.add_argument("--aws-bin", default="aws", help="AWS CLI binary.")
    parser.add_argument("--terraform-bin", default="terraform", help="Terraform binary.")
    return parser.parse_args()


ARGS = parse_args()
ARGS.tf_dir = Path(ARGS.tf_dir).resolve()
ARGS.repo_root = ARGS.tf_dir.parent
if ARGS.backup_vault_name is None:
    ARGS.backup_vault_name = f"{ARGS.environment_name}-{ARGS.region}"
if ARGS.run_imports and not ARGS.wait:
    raise SystemExit("--run-imports requires --wait so resources exist before Terraform imports run.")

account_id = aws_json("sts", "get-caller-identity")["Account"]
if ARGS.iam_role_arn is None:
    ARGS.iam_role_arn = f"arn:aws:iam::{account_id}:role/{ARGS.environment_name}-aws-backup"

AURORA_SPECS = [
    AuroraSpec(name="catalog", engine="aurora-mysql", instance_class="db.t3.medium", security_group_output="catalog_security_group_id"),
    AuroraSpec(name="orders", engine="aurora-postgresql", instance_class="db.t3.medium", security_group_output="orders_security_group_id"),
]
DYNAMO_SPEC = DynamoSpec(name="carts")


def main():
    outputs = load_terraform_outputs()
    recovery_points = list_recovery_points()

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    output_dir = ARGS.tf_dir / "dr-recovery" / timestamp
    output_dir.mkdir(parents=True, exist_ok=True)

    catalog_point = latest_recovery_point(recovery_points, AURORA_SPECS[0].recovery_suffix, ARGS.catalog_recovery_point_arn)
    orders_point = latest_recovery_point(recovery_points, AURORA_SPECS[1].recovery_suffix, ARGS.orders_recovery_point_arn)
    carts_point = latest_recovery_point(recovery_points, DYNAMO_SPEC.recovery_suffix, ARGS.carts_recovery_point_arn)

    catalog = restore_aurora(AURORA_SPECS[0], catalog_point, outputs)
    orders = restore_aurora(AURORA_SPECS[1], orders_point, outputs)
    carts = restore_dynamodb(DYNAMO_SPEC, carts_point)

    manifest = {
        "region": ARGS.region,
        "environment_name": ARGS.environment_name,
        "backup_vault_name": ARGS.backup_vault_name,
        "catalog": catalog,
        "orders": orders,
        "carts": carts,
    }
    manifest_path = output_dir / "restore-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="ascii")

    import_script = write_import_script(output_dir, catalog, orders, carts)

    print(f"Wrote restore manifest to {manifest_path}", file=sys.stderr)
    print(f"Wrote Terraform import script to {import_script}", file=sys.stderr)

    if ARGS.run_imports:
        run([str(import_script)], cwd=ARGS.repo_root, capture_output=False)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        if exc.stderr:
            sys.stderr.write(exc.stderr)
        sys.exit(exc.returncode)
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
