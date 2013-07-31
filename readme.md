# ELT Buildpack

### Fast, scriptable table-level copy from Postgres to Postgres

Most data warehousing is done using an ETL pattern.  ETL stands for
Extract, Transform, and Load and usually refers to extracting data,
modifying it "in flight" - so either on a file system or in memory, and
loading that data into a different data store.  This pattern is mostly
useful for converting incompatible data formats, such as CSV and XML
into something more structured such as SQL.

The ELT pattern can be used where the data formats are similar (ie:
two postgres tables) and the transform, if any, can be handled by the
final data store (ie: SQL updates).  In ELT we Extract and Load the
data because it is quick and cheap to do that, and then use SQL statements
on the loaded data to make any necessary transformations.

This repository is meant to be used as a Heroku app that facilitates
the bulk copy of tables from any Postgres database to another and running
SQL queries against the copied data.  The core of the repository is the
psql binary and a simple wrapper script called `extract_and_load`
that makes it easy pipe COPY TO commands in one database to
COPY FROM commands in another.

## Setup

    heroku create --buildpack http://codon-buildpacks.s3.amazonaws.com/buildpacks/csquared/elt.tgz

## Use

    ./bin/extract_and_load <specfile>

The `extract_and_load` wrapper runs the postgres COPY TO and COPY FROM commands
by using a "specfile", which is just a YAML description of which table(s), fields
and databases you'd like to use for the copy.

Here's an example spec:

We assumed `ANOTHER_DATABASE_URL` and `DATABASE_URL` are defined in your environment.

### example_spec.yml

    -
      source_db: ANOTHER_DATABASE_URL
      destination_db: DATABASE_URL
      source_table: users
      destination_table: users
      fields:
        id: int
        first_name: text
        last_name: text
        billable: boolean

You would run this file with:

    > ./bin/extract_and_load example_spec.yml

`extract_and_load` will then export the `id`, `first_name`, `last_name`, and `billable`
columns from the users table in the postgres database at `ANOTHER_DATABASE_URL` and create
a new table in the postgres database at `DATABASE_URL` with only those columns using the
data types `int`, `text`, `text`, and `boolean`.

Although this example is a bit simplistic, it shows how easy copying an entire table
from one database to another is.

## Concurrency

All tables listed in a spec file are copied over concurrently.  For serial execution just
use multiple spec files and run the `extract_and_load` command on each one.

## Scheduling

Because the copy jobs are simple UNIX scripts, it is also straightforward to wrap them
into more complex tasks and schedule them using Heroku Scheduler.

For example, let's say I had two import scripts I wanted to run every hour, described
in files `first_spec.yml` and `second_spec.yml`.

I would create the following wrapper script:

#### bin/hourly_import_job

    # /usr/bin/env sh

    ./bin/extract_and_load first_spec.yml
    ./bin/extract_and_load second_spec.yml

You could then use Heroku Scheduler to run `bin/hourly_import_job` with an hourly
frequency.  That's it.

## Transform

Transforms are handled by writing sql to a file, then using psql to execute the sql
against the target database.  For example:

    time cat "sql/fixup_invoices.sql" | bin/psql "$DATABASE_URL" -E
    time bin/psql "$DATABASE_URL" -E -c "create index on invoices(id)"


## Advanced uses

### WHERE clauses

WHERE clauses can be included to filter the data.  They are included
in the `where` key and are an array of clauses that are ANDed together.

    -
      source_db: ANOTHER_DATABASE_URL
      destination_db: DATABASE_URL
      source_table: users
      destination_table: users
      fields:
        id: int
        first_name: text
        last_name: text
        billable: boolean
      where:
        - "created_at > now() - '1 month'::interval"

### Variable substitution

Somtimes it will make sense to configure the query. `extract_and_load` supports
simple text substition on the spec file before it is parsed.  Anything in the
spec file that begins with a dollar sign `$` is replaced by a command line
parameter using the double-dash syntax.  For example:

This spec:

    -
      source_db: ANOTHER_DATABASE_URL
      destination_db: DATABASE_URL
      source_table: users
      destination_table: users
      fields:
        id: int
        first_name: text
        last_name: text
        billable: boolean
      where:
        - created_at > '$creation-cutoff'

Run with this command:

    ./bin/extract_and_load example_spec.yml --creation-cutoff 2013-06-01

Will be exported with the following WHERE condition:

    WHERE created_at > '2013-06-01'

## Schemas

If the environment variable `current_build` is set, `extract_and_load` will
copy data to that schema instead of the public one.  You have to create the schema
in your database before using this feature.

`extract_and_load` doesn't handle detecting and
creating the schema because the `IF NOT EXISTS` clause has been removed from the
`CREATE SCHEMA` command in postgresql 9.2 and above.
