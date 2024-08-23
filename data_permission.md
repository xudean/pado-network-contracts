# Data Permission Control

```mermaid
sequenceDiagram
participant DataUser
participant TaskMgt
participant DataMgt
participant DataPermission
DataUser ->> +TaskMgt: submitTask
TaskMgt  ->> +DataMgt: getPermittedDataById
DataMgt  ->> +DataPermission: isPermitted
DataPermission  -->> -DataMgt: return
DataMgt         -->> -TaskMgt: return
TaskMgt         -->> -DataUser: return
```

- The `getPermittedDataById` is restricted to be called by TaskMgt when `Data User` submit tasks.
- For workers, `getDataById` should be called to retrive Data.
- For data users, `isDataPermitted` should be called before submitting tasks.
