The goal of this project is to facilitate easy programmatic changes to a database (known as "database revisions" or "database migrations"). Currently, only a [specification](#database-schema-versioning-specification) has been released; a related set of tools and implementations will be released in the future.

# Utilities
The following utilities implement the [*db-schema-spec* specification](#database-schema-versioning-specification)
 * [bin/util/migrate-mysql.sh](/bin/util/migrate-mysql.sh) - migrate a *mysql* database
 * [bin/util/migrate-mongo.sh](/bin/util/migrate-mongo.sh) - migrate a *mongo* database

# Database Schema Versioning Specification
The *Database Schema Versioning Specification* (or "db-schema-spec" for short) describes the structure of a single conceptual database and its successive revisions.

#### Latest Release
 * **db-schema-spec** : [`1.2`](https://github.com/katmore/database-schema-versioning/releases/tag/v1.2.0) - Major update v1.2

#### Major update history
 * *db-schema-spec : [`1.2`](https://github.com/katmore/database-schema-versioning/releases/tag/v1.2.0)* - Major update v1.2
 * *db-schema-spec : [`1.1`](https://github.com/katmore/database-schema-versioning/releases/tag/v1.1.0)* - Initial release
 * *db-schema-spec : `1.0`* - Development/pre-release
 
---
## Terminology
The key words "must", "must not", "required", "shall", "shall not", "should", "should not", "recommended", "may", and "optional" in this document are to be interpreted as described in [RFC 2119](https://tools.ietf.org/html/rfc2119).

Additionally, the key words outlined in the following section shall be interpreted as described.

 * **database schema** : A single conceptual database with a continuous successive history.
 * **schema name**  : A "name" assigned to a particular *database schema*; it should be reasonably brief and descriptive.
 * **schema version** : A numeric "version" which identifies a particular state of a database. It must be an unsigned numeric value; either a whole number (integer) or a decimal (float). This numeric constraint makes it trivial to keep sorting/succession consistent across different programming environments.

---
## Resources
This section provides details regarding the directory structure and [JSON object](https://tools.ietf.org/html/rfc7159#section-4) files used to describe a [*database schema*](#terminology) and its [*schema versions*](#terminology).

  * [**schema root**](#schema-root) : The directory which contains all resources needed to describe a single [*database schema*](#terminology).
  * [**schema.json**](#schemajson) : The file containing a [JSON object](https://tools.ietf.org/html/rfc7159#section-4) that describes a single [*database schema*](#terminology). This file must be contained within the [*schema root*](#schema-root).
  * [**version root**](#version-root) : A directory which contains all *resources* needed to describe a single [*schema version*](#terminology).
  * [**version.json**](#schemajson) : A file containing a [JSON object](https://tools.ietf.org/html/rfc7159#section-4) that describes a single [*schema version*](#terminology). This file must be contained within the [*version root*](#resources).
  
---
### schema root
The *schema root* must be a directory that contains all resources needed to describe a single [*database schema*](#terminology). It should be a directory specific to the schema and should be the same name as the schema. It must contain a [*schema.json*](#schemajson) file.

Consider the example project named `my-project` as seen in the section below. It has the following directory structure: the top-level contains a directory named `db-schema` that holds all database schemas, which, in turn, contains directories for the specifications of the [*schemas*](#terminology) having the names `something` and `another something`. Therefore, the path `my-project/db-schema/something` is the [*schema root*](#schema-root) for the [*database schema*](#terminology) `something`; likewise, the path `my-project/db-schema/something` is the [*schema root*](#schema-root) for the [*database schema*](#terminology) `another-something`.

**Example `my-project` contents...**
```txt
my-project/ ->
   bin/ ->
      ...
   db-schema/ ->
      something/ ->
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
      another-something/ ->
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
The **schema.json** file contains a single [JSON object](https://tools.ietf.org/html/rfc7159#section-4) that describes a [*database schema*](#terminology). It must be located in the top-level of the [*schema root*](#schema-root) which it describes. The [JSON object](https://tools.ietf.org/html/rfc7159#section-4) must contain all the properties as described in the following bullet-point list.

 * **db-schema-spec** : The [Database Schema Versioning](#release-history) specification release being used in this [JSON object](https://tools.ietf.org/html/rfc7159#section-4).
 * **name** : The [*schema name*](#terminology) of the [*database schema*](#terminology) being described.
 * **system** : The database system of the [*database schema*](#terminology) being described; e.g. "mysql", "mongo", "reddis", etc.
 * **current-version** : The current [*schema-version*](#terminology) of the [*database schema*](#terminology).
 * **version-history** : An object with each property name corresponding to a [*schema-version*](#terminology) and the value being the path to the corresponding [*version root*](#resources) directory (relative to the [*schema root*](#schema-root)). Therefore, each path must point to a directory containing a [*version.json*](#versionjson) file.

***schema.json* example #1...**
```json
{
   "db-schema-spec": "1.1",
   "name" : "something",
   "system" : "mysql",
   "current-version" : "20.043001",
   "version-history" : {
      "20.043001" : "2020/043001",
      "19.081501" : "2019/081501",
      "..."
   }
}
```

***schema.json* example #2...**
```json
{
   "db-schema-spec": "1.1",
   "name" : "another-something",
   "system" : "mysql",
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
The **version.json** file contains a single [JSON object](https://tools.ietf.org/html/rfc7159#section-4) that describes a [*schema-version*](#terminology). It must be contained in the top level of the [*version root*](#resources) it describes. 

The [JSON object](https://tools.ietf.org/html/rfc7159#section-4) in [*version.json*](#versionjson) must contain ALL of the following properties as described:

  * **db-schema-spec** : The [Database Schema Versioning](#release-history) specification release being used in this [JSON object](https://tools.ietf.org/html/rfc7159#section-4).
  * **schema** : The name of database schema. It should be cross-checked to match the `name` property of the referring [*schema.json*](#schemajson) file.
  * **version** : A string with the value of the [*schema version*](#terminology) that is being described. It should be cross-checked to match with the referring property in the `version-history` object of the [*schema.json*](#schemajson) file.
  * **source** : An array of strings; each value is a path (relative to the [*version root*](#resources)) to a source file that must be successfully executed. Each source file must be executed in the order it occurs in the array.

***version.json* example #1...**
```json
{
   "db-schema-spec": "1.1",
   "schema" : "something",
   "system" : "mysql",
   "version" : "200430.01",
   "command" : [
      "revisions.sql"
   ]
}
```

***version.json* example #2...**
```json
{
   "db-schema-spec": "1.1",
   "schema" : "another-something",
   "system" : "mysql",
   "version" : "1.0",
   "command" : [
      "DAL-revisions.sql",
      "BLL-revisions.sql"
   ]
}
```

# Legal
This software is distributed under the terms of the [MIT license](LICENSE) or the [GPLv3](GPLv3) license.

Copyright (c) 2015-2020, Doug Bird. All rights reserved.
