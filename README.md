# Azure Databricks ETL

Example based on [this tutorial](https://learn.microsoft.com/en-us/azure/databricks/scenarios/databricks-extract-load-sql-data-warehouse).

```sh
terraform -chdir=infra init
terraform -chdir=infra apply -auto-approve
```

After the Azure Databricks workspace is ready, create a cluster.

In the dedicated pool:

```sql
CREATE MASTER KEY;
```