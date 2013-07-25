DATABASE_URL=elt-buildpack-test ./bin/extract_and_load test/spec.yml
psql elt-buildpack-test -c "SELECT * from new_things"
