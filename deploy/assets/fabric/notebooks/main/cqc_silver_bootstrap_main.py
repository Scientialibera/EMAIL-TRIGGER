# MAGIC %run ../modules/cqc_silver_bootstrap_module


def main(executionData: dict) -> dict:
    table_name = executionData.get("table_name") or executionData.get("table") or "dbo.cqc_email_silver"
    ensure_silver_table(table_name)
    return {"status": "ok", "table": table_name}
