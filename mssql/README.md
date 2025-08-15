# SQL Server
```
docker compose up
```

- con
    - mssql://sa:YourStrong%21Passw0rd@localhost:1433
    - python
    ```python
    from urllib.parse import quote_plus
    con = f'mssql+pymssql://sa:{quote_plus("YourStrong!Passw0rd")}@localhost:1433'
    ```