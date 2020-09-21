# sftpgo bindings

Hand written HTTP bindings for a subset of the [drakkan/sftpgo](https://github.com/drakkan/sftpgo) REST API.


Reference schema: https://github.com/drakkan/sftpgo/blob/master/httpd/schema/openapi.yaml

## History

Why not use code generation to produce HTTP client code for the OpenAPI definition
that is available?

Because it generates massive amounts of boilerplate code (+10K SLOC) which
make is a maintenance nightmare. Additionally any differences between the API
docs and the API, or any failures in the code generator produce hard to track
bugs.

It turned out to be easier to just hand code a few methods.

## Requirements

- gem faraday
- recent ruby version
