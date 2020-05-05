# Database Schema Versioning
This README describes a means to facilitate automated tasks that deploy changes to databases; typically known as "database revisions" or "database migrations". The goal is to provide a clear methodology to describe a “database schema” (and its revisions) that is straightforward to understand and easy to programatically access.

## Specification
```json
---
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
 * **migrate source file** : A file that contains source code that, if executed, may permanently affect a deployed *database schema*.

---
## Resources
  * [**schema root**](#schema-root) : The directory which contains all resources needed to describe a single database schema.
  * [**schema.json**](#schemajson) : The file containing the a json object that describes a single *database schema*. It must be contained within the *schema root*.
  * [**version root**](#version-root) : A directory which contains all resources needed to describe a single *schema version*.
  * [**version.json**](#schemajson) : A file containing a json object that describes a single *schema version*.
  
---
### schema root
The *schema root* must be a directory that contains all resources needed to describe a single database schema. It should be a directory specific to the schema and should be the same name as the schema. It must contain a *schema.json* file.

The following is an example directory listing containing two *schema root*'s. The path *my-project/db-schema/some-schema* is the **"schema root"** for "*some-schema*"; likewise, the path *my-project/resources/sql-schema/another-schema* is the **"schema root"** "*another-schema*"...
```txt
my-project/ ->
   db-schema/ ->
      some-schema/ ->
         schema.json
         2019/ ->
            19.0815/ ->
               version.json
         2020/ ->
            20.0430/ ->
               version.json
               revisions.sql
      another-schema/ ->
         schema.json
         1.0/ ->
            version.json
            revisions.sql
         1.1/ ->
            version.json
            revisions.sql
```

---
### schema.json
The **schema.json** file contains a single json object that describes a *database schema*. It must be located in the top-level of the *schema root* which it describes. The json object must contain all the properties as described in the following bullet-point list.

 * **db-schema-spec** : The [Database Schema Versioning](https://github.com/katmore/database-schema-versioning#Specification-Details) specification version being used in this json object.
 * **name** : The *schema name* of the *database schema* being described.
 * **system-type** : The database system of the *database schema* being described; e.g. "mysql", "mongo", "reddis", etc.
 * **current-version** : The current *schema-version* of the *database schema*.
 * **version-history** : An object with each property name corresponding to a *schema version* and the value being the path to the corresponding *version root* directory (relative to the *schema root*); thus each path must point to a directory containing a *version.json* file.

**schema.json* example...**
```json
{
   "db-schema-spec": "1.1.0",
   "name" : "some-schema",
   "system-type" : "mysql",
   "current-version" : "200430",
   "version-history" : {
      "20.043001" : "2020/0430",
      "19.081501" : "2019/0815",
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

The json object in *version.json* must contain AT LEAST ONE of the following properties as described:

  * **migrate-source** : An array of strings where each element is a relative path to a *migrate source file* that must be executed successfully on a deployed schema. Each source file must be executed in the order it is contained within the array.
  * **migrate-command** : An array of strings where each element is a command that must be executed successfully of a deployed schema. Each command must be executed in the order it is contained within the array.

#### version.json examples
**version.json* example #1...**
```json
{
   "db-schema-spec": "1.1.0",
   "schema" : "some-schema",
   "system-type" : "mysql",
   "version" : "200430.01",
   "migrate-source" : [
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
   "migrate-command" : [
      "ALTER TABLE some_table ADD COLUMN `foo` char(3) DEFAULT NULL",
      "INSERT INTO some_table SET foo='bar'"
   ]
}
```
