NAMESPACE := logging
RELEASE := helm-es-security
STACK_VERSION := 7.9.1
ELASTICSEARCH_IMAGE := docker.elastic.co/elasticsearch/elasticsearch:$(STACK_VERSION)
DNS := elastic

secrets-elastic:
	docker rm -f elastic-helm-charts-certs || true
	rm -f elastic-certificates.p12 elastic-certificate.pem elastic-certificate.crt elastic-stack-ca.p12 || true
	password=$$([ ! -z "$$ELASTIC_PASSWORD" ] && echo $$ELASTIC_PASSWORD || echo $$(docker run --rm busybox:1.31.1 /bin/sh -c "< /dev/urandom tr -cd '[:alnum:]' | head -c20")) && echo $$password &&  \
	docker run --name elastic-helm-charts-certs -i -w /app \
		$(ELASTICSEARCH_IMAGE) \
		/bin/sh -c " \
			elasticsearch-certutil ca --out /app/elastic-stack-ca.p12 --pass '' && \
			elasticsearch-certutil cert --name $(DNS) --dns $(DNS) --ca /app/elastic-stack-ca.p12 --pass '' --ca-pass '' --out /app/elastic-certificates.p12" && \
	docker cp elastic-helm-charts-certs:/app/elastic-certificates.p12 ./ && \
	docker rm -f elastic-helm-charts-certs && \
	openssl pkcs12 -nodes -passin pass:'' -in elastic-certificates.p12 -out elastic-certificate.pem && \
	openssl x509 -outform der -in elastic-certificate.pem -out elastic-certificate.crt && \
	kubectl -n $(NAMESPACE) create secret generic elastic-certificates --from-file=elastic-certificates.p12 && \
	kubectl -n $(NAMESPACE) create secret generic elastic-certificate-pem --from-file=elastic-certificate.pem && \
	kubectl -n $(NAMESPACE) create secret generic elastic-certificate-crt --from-file=elastic-certificate.crt && \
	kubectl -n $(NAMESPACE) create secret generic elastic-credentials  --from-literal=password=$$password --from-literal=username=elastic && \
	rm -f elastic-certificates.p12 elastic-certificate.pem elastic-certificate.crt elastic-stack-ca.p12

secrets-kibana:
	encryptionkey=$$(docker run --rm busybox:1.31.1 /bin/sh -c "< /dev/urandom tr -dc _A-Za-z0-9 | head -c50") && \
	kubectl -n $(NAMESPACE) create secret generic kibana --from-literal=encryptionkey=$$encryptionkey

clear-certs:
	kubectl -n $(NAMESPACE) delete secrets elastic-certificate-crt elastic-certificate-pem elastic-certificates elastic-credentials

init:
	helm repo add stable https://kubernetes-charts.storage.googleapis.com
	helm repo add elastic https://helm.elastic.co
	helm repo add bitnami https://charts.bitnami.com/bitnami
	helm repo update
	kubectl create ns logging

install-elastic:
	helm upgrade --install elastic elastic/elasticsearch -n $(NAMESPACE) -f ./yaml/values-elastic.yaml --version 7.9.1

install-kibana:
	helm upgrade --install kibana elastic/kibana -n $(NAMESPACE) -f ./yaml/values-kibana.yaml --version 7.9.1

install-kafka:
	helm upgrade --install kafka bitnami/kafka -n $(NAMESPACE) -f ./yaml/values-kafka.yaml --version 11.8.4

install-logstash:
	helm upgrade --install logstash elastic/logstash -n $(NAMESPACE) -f ./yaml/values-logstash.yaml --version 7.9.1

install:
	make install-elastic
	echo "Waiting for elastic to run for 10 seconds"
	sleep 10
	make install-kibana
	echo "Waiting for kibana to run for 10 seconds"
	sleep 10
	make install-kafka
	echo "Waiting for kafka to run for 10 seconds"
	sleep 10
	make install-logstash

purge-helm:
	helm delete -n $(NAMESPACE) elastic
	helm delete -n $(NAMESPACE) kibana
	helm delete -n $(NAMESPACE) kafka
	helm delete -n $(NAMESPACE) logstash