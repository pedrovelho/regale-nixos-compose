# Introduction

Composition to run facet directly on a cluster with 40.

## Running locally

```shell
nix develop --command zsh
nxc build -f docker # need to add changes on git to flake to consider them
nxc build -f docker # need to add changes on git to flake to consider them

nxc start # will use last built version 
```
