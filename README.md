# ELK Stack - Helm Chart

This repository contains Production Ready ELK stack.

It contains:
  - ElasticSearch
  - Kibana
  - Logstash
  - Kafka
  - Zookeeper

### Configuration
You can change the namespace in which you want to deploy be changing the `NAMESPACE` in `Makefile`.

Change the `DNS` in `Makefile` if required.
**Note this can  break the some functionality if not configured correctly.

### Initialization
##### Adding the repository and creating the namespace

```sh
$ make init
```

##### Create the certificate files for elasticsearch and kibana:
```sh
$ make secrets-elastic
$ make secrets-kibana
```

### For installing all the components
```sh
$ make install
```

### For installing individual components
```sh
$ make install-elastic
$ make install-kibana
$ make install-kafka
$ make install-logstash
```

### For removing everything
```sh
$ make clear-certs
$ make purge-helm
```

Feel free to create an issue or PR for any changes.*
