#!/bin/sh


kafka_bin_directory="./bin"
kafka_conf_directory="./config"

if [ ! -d "$kafka_bin_directory" ] || [ ! -d "$kafka_conf_directory" ]
then
	echo "Kafka directory NOT found ! Please place and run this script from the root Kafka directory (e.g. kafka_2.11-1.0.0/my-script-kafka.sh)"

else
	if [ ! -z "$1" ] && [ ! -z "$2" ]
	then
		if [ "$1" = "-t" ] || [ "$1" = "--topic" ]
		then
			TOPIC="$2"
		else
			echo "HOW TO: $0 <[-t | --topic] 'some-topic-name'> (topic defaults to 'test-topic')"
			return 1
		fi
	else
		TOPIC="test-topic"
	fi


	# Make sure zookeeper is launched:
	# $ telnet localhost 2181
	# then run stats


	# Otherwise
	# start_zookeeper="${kafka_bin_directory}/zookeeper-server-start.sh ${kafka_conf_directory}/zookeeper.properties";
	# echo "Starting Zookeeper server ..."
	# eval "${start_zookeeper}" &>> /dev/null &disown;
	# echo "Done !"

	# Start Kafka server
	start_kafka_server="${kafka_bin_directory}/kafka-server-start.sh ${kafka_conf_directory}/server.properties";
	echo "Starting Kafka server ..."
	eval "${start_kafka_server}" &> /dev/null &
	echo "Done !"



	# Start consumer from passed topic argument or 'test-topic'

	start_consumer="${kafka_bin_directory}/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic ${TOPIC} --from-beginning";
	echo "Starting Kafka consumer on topic ${TOPIC} ..."
	eval "${start_consumer}";
fi
