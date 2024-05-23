# Exemplo pra rodar em OpenShift

## Crie a aplicação via CLI

```sh
oc new-project myfastapi
```

```sh
oc new-app openshift/python:3.9-ubi8~https://github.com/tvieira/myfastapi.git --name my-fastapi
```

```sh
oc expose svc/hello-world
```
