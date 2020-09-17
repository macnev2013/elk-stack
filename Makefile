NAMESPACE := logging
IMAGE_TAG := 8.0.0-SNAPSHOT
ELASTICSEARCH_IMAGE := docker.elastic.co/elasticsearch/elasticsearch:$(IMAGE_TAG)
DNS := elastic

init:
	helm repo add stable https://kubernetes-charts.storage.googleapis.com
	helm repo add elastic https://helm.elastic.co
	helm repo add bitnami https://charts.bitnami.com/bitnami
	helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com
	helm repo update
	kubectl create ns $(NAMESPACE)

secrets-elastic:
	docker rm -f elastic-helm-charts-certs || true
	rm -f elastic-certificates.p12 elastic-certificate.pem elastic-certificate.crt elastic-stack-ca.p12 || true
	password=$$([ ! -z "$$ELASTIC_PASSWORD" ] && echo $$ELASTIC_PASSWORD || echo $$(docker run --rm busybox:1.31.1 /bin/sh -c "< /dev/urandom tr -cd '[:alnum:]' | head -c20")) && echo "Password for ElasticSearch: "$$password &&  \
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

secret:
	make secrets-elastic
	make secrets-kibana

clear-certs:
	kubectl -n $(NAMESPACE) delete secrets elastic-certificate-crt elastic-certificate-pem elastic-certificates elastic-credentials kibana

install-elastic:
	helm upgrade --install elastic elastic/elasticsearch -n $(NAMESPACE) --set imageTag=$(IMAGE_TAG) -f ./yaml/values-elastic.yaml --version 7.9.1

install-kibana:
	helm upgrade --install kibana elastic/kibana -n $(NAMESPACE) --set imageTag=$(IMAGE_TAG) -f ./yaml/values-kibana.yaml --version 7.9.1

install-kafka:
	helm upgrade --install kafka incubator/kafka -n $(NAMESPACE) -f ./yaml/values-kafka.yaml --version 0.21.2

install-kafka-manager:
	password=$$([ ! -z "$$ELASTIC_PASSWORD" ] && echo $$ELASTIC_PASSWORD || echo $$(docker run --rm busybox:1.31.1 /bin/sh -c "< /dev/urandom tr -cd '[:alnum:]' | head -c20")) && echo "Password for Kafka: "$$password && \
	helm upgrade --install kafka-manager stable/kafka-manager -n $(NAMESPACE) --set basicAuth.password=$(password) -f ./yaml/values-kafka-manager.yaml  --version 2.3.1

install-logstash:
	helm upgrade --install logstash elastic/logstash -n $(NAMESPACE) --set imageTag=$(IMAGE_TAG) -f ./yaml/values-logstash.yaml --version 7.9.1

install-filebeat:
	helm upgrade --install filebeat elastic/filebeat -n $(NAMESPACE) --set imageTag=$(IMAGE_TAG) -f ./yaml/values-filebeat.yaml --version 7.9.1

install:
	make install-elastic
	make install-kibana
	make install-kafka
	make install-kafka-manager
	make install-logstash
	make install-filebeat

install-elk:
	make install-elastic
	make install-kibana
	make install-kafka
	make install-kafka-manager
	make install-logstash

uninstall:
	helm delete -n $(NAMESPACE) elastic
	helm delete -n $(NAMESPACE) kibana
	helm delete -n $(NAMESPACE) kafka
	helm delete -n $(NAMESPACE) kafka-manager
	helm delete -n $(NAMESPACE) logstash
	helm delete -n $(NAMESPACE) filebeat

deploy:
	make init
	make secret
	make install

clean:
	make clear-certs
	make uninstall
