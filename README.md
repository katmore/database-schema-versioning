# Database Schema Versioning
This goal of this project is to establish a specification to describe database revisions that lends itself to programmatic access, yet is easy for a human to examine.

## Specification
```json
---
Title: Database Schema Versioning
Version: 1.1.0
Maintainer: D. Bird <retran@gmail.com>
Authors:
- D. Bird <retran@gmail.com>
...
```

---
## Terminology
 * **schema name**  : The "name" for a particular schema; it should be brief and reasonably descriptive.
 * **schema version** : A numeric "version" which identifies a particular revision of a database schema. It must be a numeric value, expressed either as an integer or a float using a decimal point (this makes it simple to keep sorting/succession consistent across different programming environments).

---
## Resources
  * [**schema root**](#schema-root) : The directory which contains all resources needed to describe a single database schema.
  * [**schema.json**](#schemajson) : The file containing the a json object that describes a single *database schema*. It must be contained within the *schema root*.
  * [**version root**](#version-root) : A directory which contains all resources needed to describe a single *schema version*.
  * [**version.json**](#schemajson) : A file containing a json object that describes a single *schema version*.
  
---
### schema root
The *schema root* must be a directory that contains all resources needed to describe a single database schema. It should be a directory specific to the schema and should be the same name as the schema. It must contain a *schema.json* file.

Consider an example project named `my-project` with the following directory structure: it contains a directory to hold all database schemas named "db-schema", which, in turn, contains specifications for two database schemas having the names `some-schema` and `another schema`. Therefore, the path `my-project/db-schema/some-schema` is the *schema root* for `some-schema`; likewise, the path `my-project/db-schema/some-schema` is the *schema root* for `another-schema`.

**Example project contents...**
```txt
my-project/ ->
   bin/ ->
      ...
   db-schema/ ->
      some-schema/ ->
         schema.json
         2019/ ->
            19.081501/ ->
               BLL-revisions.sql
               DAL-revisions.sql
               version.json
         2020/ ->
            20.043001/ ->
               revisions.sql
               version.json
      another-schema/ ->
         schema.json
         1.0/ ->
            revisions.sql
            version.json
         1.1/ ->
            revisions.sql
            version.json
   src/ ->
      ...
```

---
### schema.json
The **schema.json** file contains a single json object that describes a *database schema*. It must be located in the top-level of the *schema root* which it describes. The json object must contain all the properties as described in the following bullet-point list.

 * **db-schema-spec** : The [Database Schema Versioning](https://github.com/katmore/database-schema-versioning#Specification-Details) specification version being used in this json object.
 * **name** : The *schema name* of the *database schema* being described.
 * **system-type** : The database system of the *database schema* being described; e.g. "mysql", "mongo", "reddis", etc.
 * **current-version** : The current *schema-version* of the *database schema*.
 * **version-history** : An object with each property name corresponding to a *schema version* and the value being the path to the corresponding *version root* directory (relative to the *schema root*). Therefore, each path must point to a directory containing a *version.json* file.

**schema.json* example #1...**
```json
{
   "db-schema-spec": "1.1.0",
   "name" : "some-schema",
   "system-type" : "mysql",
   "current-version" : "20.043001",
   "version-history" : {
      "20.043001" : "2020/043001",
      "19.081501" : "2019/081501",
      "..."
   }
}
```

**schema.json* example #2...**
```json
{
   "db-schema-spec": "1.1.0",
   "name" : "another-schema",
   "system-type" : "mysql",
   "current-version" : "1.1",
   "version-history" : {
      "1.1" : "1.1",
      "1.0" : "1.0",
      "..."
   }
}
```
---
### version.json
The **version.json** file contains a single json object that describes a *schema version*. It must be contained in the top level of the *version root* it describes. 

The json object in *version.json* must contain ALL of the following properties as described:

  * **schema** : The name of database schema. It should be cross-checked to match the *name* property of the referring *schema.json* file.
  * **version** : A string with the value of the *schema version* that is being described. It should be cross-checked to match with the referring property in the *version-history* object of the *schema.json* file.
  * **source** : An array of strings; each value is a path (relative to the *version root*) to a source file that must be successfully executed. Each source file must be executed in the order it appears in the array.

#### version.json examples
**version.json* example #1...**
```json
{
   "db-schema-spec": "1.1.0",
   "schema" : "some-schema",
   "system-type" : "mysql",
   "version" : "200430.01",
   "command" : [
      "revisions.sql"
   ]
}
```

**version.json* example #2...**
```json
{
   "db-schema-spec": "1.1.0",
   "schema" : "another-schema",
   "system-type" : "mysql",
   "version" : "1.0",
   "command" : [
      "DAL-revisions.sql",
      "BLL-revisions.sql"
   ]
}
```
