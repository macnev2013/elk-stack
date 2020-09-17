# ELK Stack - Helm Chart

This repository contains Production Ready ELK stack.

It contains:
  - ElasticSearch
  - Kibana
  - Logstash
  - Kafka
  - Kafka-Manager
  - Zookeeper

### Configuration
You can change the namespace in which you want to deploy be changing the `NAMESPACE` in `Makefile`.

Change the `DNS` in `Makefile` if required.
`**Note this can  break the some functionality if not configured correctly.`

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

### For creating certs / helm
```sh
$ make secret
$ make install
```

### For removing certs / helm
```sh
$ make clear-certs
$ make uninstall
```

### For deploying elk with certs
```sh
$ make deploy
```

### For removing everything
```sh
$ make clean
```

### For installing individual components
```sh
	make install-elastic
	make install-kibana
	make install-kafka
	make install-kafka-manager
	make install-logstash
	make install-filebeat
```


Feel free to create an issue or PR for any changes.
